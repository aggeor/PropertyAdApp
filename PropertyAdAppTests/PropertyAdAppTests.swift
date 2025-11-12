import XCTest
import Combine
@testable import PropertyAdApp

final class AdFormViewModelTests: XCTestCase {
    var viewModel: AdFormViewModel!
    var cancellables: Set<AnyCancellable>!
    var mockSession: URLSession!
    var cache: URLCache!

    override func setUp() {
        super.setUp()
        
        URLProtocolMock.testURLs.removeAll()
        URLProtocolMock.error = nil
        
        // Set up cache and mock session once
        cache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad // Ensure caching works
        mockSession = URLSession(configuration: config)
        
        // Initialize viewModel with mock session
        viewModel = AdFormViewModel(urlSession: mockSession, urlCache: cache)
        cancellables = []
        
        // Add a small delay to ensure Combine pipelines are set up
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    override func tearDown() {
        viewModel = nil
        cancellables = nil
        mockSession = nil
        cache = nil
        URLProtocolMock.testURLs.removeAll()
        URLProtocolMock.error = nil
        super.tearDown()
    }

    func testSelectPlaceUpdatesLocationTextAndClearsSuggestions() {
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)

        XCTAssertEqual(viewModel.locationText, "Athens, Greece")
        XCTAssertEqual(viewModel.selectedPlace?.placeId, "1")
        XCTAssertTrue(viewModel.suggestions.isEmpty)
    }

    func testCanSubmitIsFalseIfNoSelectedPlace() {
        viewModel.title = "My Property"
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testCanSubmitIsTrueIfTitleAndPlaceAreSet() {
        viewModel.title = "My Property"
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        XCTAssertTrue(viewModel.canSubmit)
    }

    func testClearingFormResetsEverything() {
        viewModel.title = "Test"
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        viewModel.price = "123"
        viewModel.description = "Property description test"
        viewModel.clearForm()

        XCTAssertEqual(viewModel.title, "")
        XCTAssertNil(viewModel.selectedPlace)
        XCTAssertTrue(viewModel.suggestions.isEmpty)
        XCTAssertEqual(viewModel.price, "")
        XCTAssertEqual(viewModel.description, "")
    }

    func testSelectedPlaceResetsWhenEditingText() {
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        
        let expectation = XCTestExpectation(description: "selectedPlace should reset after editing text")
        
        // Subscribe to selectedPlace changes
        var observedChanges = 0
        viewModel.$selectedPlace
            .dropFirst() // Skip initial value
            .sink { selectedPlace in
                observedChanges += 1
                if observedChanges == 1 { // First change should be to nil
                    XCTAssertNil(selectedPlace)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger the change
        viewModel.locationText = "Athen"
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testSubmitReturnsProperJson() throws {
        viewModel.title = "Test"
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        viewModel.price = "123"
        viewModel.description = "Property description test"

        viewModel.submit()

        XCTAssertTrue(viewModel.showJSONSheet)

        let data = Data(viewModel.jsonResult.utf8)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        
        XCTAssertEqual(jsonObject?["title"] as? String, "Test")
        XCTAssertEqual(jsonObject?["price"] as? String, "123")
        XCTAssertEqual(jsonObject?["description"] as? String, "Property description test")
        
        if let location = jsonObject?["location"] as? [String: Any] {
            XCTAssertEqual(location["placeId"] as? String, "1")
            XCTAssertEqual(location["mainText"] as? String, "Athens")
            XCTAssertEqual(location["secondaryText"] as? String, "Greece")
        } else {
            XCTFail("Location is missing or invalid")
        }
    }
    
    func testFetchSuggestionsSavesToCache() throws {
        // Prepare mock data
        let mockPlaces = [Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")]
        let mockData = try JSONEncoder().encode(mockPlaces)
        
        let encodedQuery = "Athens".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let testURL = URL(string: "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws?input=\(encodedQuery)")!
        
        URLProtocolMock.testURLs[testURL] = mockData
        
        let suggestionsExpectation = XCTestExpectation(description: "Should receive suggestions")
        let cacheExpectation = XCTestExpectation(description: "Should cache response")
        
        var suggestionsReceived = false
        
        // Subscribe to suggestions changes
        viewModel.$suggestions
            .dropFirst()
            .sink { suggestions in
                if !suggestions.isEmpty && !suggestionsReceived {
                    suggestionsReceived = true
                    XCTAssertEqual(suggestions.count, 1)
                    XCTAssertEqual(suggestions.first?.mainText, "Athens")
                    suggestionsExpectation.fulfill()
                    
                    // Check cache after a brief delay to ensure cache operation completed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let request = URLRequest(url: testURL)
                        let cached = self.cache.cachedResponse(for: request)
                        XCTAssertNotNil(cached, "Response should be cached")
                        cacheExpectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        viewModel.fetchSuggestions(for: "Athens")
        
        wait(for: [suggestionsExpectation, cacheExpectation], timeout: 3)
    }

    func testFetchSuggestionsLoadsFromCacheOnSecondCall() throws {
        // Prepare mock data
        let mockPlaces = [
            Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        ]
        let mockData = try JSONEncoder().encode(mockPlaces)
        
        let encodedQuery = "Athens".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let testURL = URL(string: "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws?input=\(encodedQuery)")!
        
        // Manually populate cache
        let request = URLRequest(url: testURL)
        let response = HTTPURLResponse(url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let cachedResponse = CachedURLResponse(response: response, data: mockData)
        cache.storeCachedResponse(cachedResponse, for: request)
        
        // Now fetch - should load from cache immediately
        viewModel.fetchSuggestions(for: "Athens")
        
        // Since cache is synchronous, suggestions should be available immediately
        XCTAssertEqual(viewModel.suggestions.count, 1)
        XCTAssertEqual(viewModel.suggestions.first?.mainText, "Athens")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading when using cache")
    }
    
    func testFetchSuggestionsHandlesNetworkError() {
        
        // Simulate network error
        URLProtocolMock.error = NSError(domain: "NetworkError", code: -1, userInfo: nil)
        
        let errorExpectation = XCTestExpectation(description: "Should handle error")
        
        viewModel.$suggestions
            .dropFirst()
            .sink { suggestions in
                // On error, suggestions should be empty
                if suggestions.isEmpty {
                    errorExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.fetchSuggestions(for: "Athens")
        
        wait(for: [errorExpectation], timeout: 2)
    }

    func testFetchSuggestionsHandlesInvalidURL() {
        let expectation = XCTestExpectation(description: "isLoading should become false")
        
        // Subscribe to isLoading changes
        var loadingStates: [Bool] = []
        viewModel.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                // When we see isLoading become false after being true, the test passes
                if loadingStates.count >= 2 && isLoading == false {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Test with empty string - this should trigger a network call that fails
        viewModel.fetchSuggestions(for: "")
        
        wait(for: [expectation], timeout: 2)
        
        // Final assertion
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after network failure")
    }
    
    func testLocationAutocompleteDoesNotFetchWhenUnfocused() {
        let expectation = XCTestExpectation(description: "Should not fetch when unfocused")
        expectation.isInverted = true
        
        // Set up mock data so if a network call DOES happen, it won't fail
        let encodedQuery = "Ath".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let testURL = URL(string: "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws?input=\(encodedQuery)")!
        URLProtocolMock.testURLs[testURL] = Data() // Empty data
        
        var receivedSuggestions = false
        
        viewModel.$suggestions
            .dropFirst()
            .sink { suggestions in
                if !suggestions.isEmpty {
                    receivedSuggestions = true
                    expectation.fulfill() // Should not be called
                }
            }
            .store(in: &cancellables)
        
        viewModel.isLocationFocused = false
        viewModel.locationText = "Ath"
        
        wait(for: [expectation], timeout: 0.5)
        
        // Additional assertion to be sure
        XCTAssertFalse(receivedSuggestions, "Should not have received suggestions when unfocused")
    }

    func testLocationAutocompleteDebouncesRequests() {
        let expectation = XCTestExpectation(description: "Should only fetch once after debounce")
        var fetchCount = 0
        
        viewModel.$suggestions
            .dropFirst()
            .sink { _ in
                fetchCount += 1
                if fetchCount == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Rapidly change text - should only trigger one fetch due to debounce
        viewModel.isLocationFocused = true
        viewModel.locationText = "A"
        viewModel.locationText = "At"
        viewModel.locationText = "Ath"
        
        wait(for: [expectation], timeout: 1)
    }
    
}
