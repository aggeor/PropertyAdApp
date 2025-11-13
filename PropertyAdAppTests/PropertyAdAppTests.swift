import XCTest
import Combine
@testable import PropertyAdApp

final class AdFormViewModelTests: XCTestCase {
    // MARK: - Properties
    var viewModel: AdFormViewModel!
    var cancellables: Set<AnyCancellable>!
    var mockSession: URLSession!
    var mockCache: URLCache!

    // MARK: - Setup
    override func setUp() {
        super.setUp()
        
        // Reset global mocks before each test
        URLProtocolMock.testURLs.removeAll()
        URLProtocolMock.error = nil
        
        // Create a temporary in-memory cache of 10Mb (no disk usage)
        mockCache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 0)
        
        // Configure a mock URLSession that uses our custom URLProtocolMock
        let config = URLSessionConfiguration.ephemeral // no persistent storage for tests cache
        config.protocolClasses = [URLProtocolMock.self] // intercepts network calls
        config.urlCache = mockCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        mockSession = URLSession(configuration: config)
        
        // Inject mocks into the ViewModel
        viewModel = AdFormViewModel(urlSession: mockSession, urlCache: mockCache)
        cancellables = []
        
        // Small delay to ensure Combine pipelines are initialized
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    
    // MARK: - Teardown
    override func tearDown() {
        // Clean up references and reset mocks
        viewModel = nil
        cancellables = nil
        mockSession = nil
        mockCache = nil
        URLProtocolMock.testURLs.removeAll()
        URLProtocolMock.error = nil
        super.tearDown()
    }

    // MARK: - Unit Tests
    
    func testSelectPlaceUpdatesLocationTextAndClearsSuggestions() {
        // Given a selected place
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        
        // When selecting it in the ViewModel
        viewModel.select(place: place)

        // Then: locationText and selectedPlace should update, and suggestions clear
        XCTAssertEqual(viewModel.locationText, "Athens, Greece")
        XCTAssertEqual(viewModel.selectedPlace?.placeId, "1")
        XCTAssertTrue(viewModel.suggestions.isEmpty)
    }

    func testCanSubmitIsFalseIfNoSelectedPlace() {
        // Given a title but no selected place
        viewModel.title = "My Property"
        
        // Then form should not be submittable
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testCanSubmitIsTrueIfTitleAndPlaceAreSet() {
        // Given a valid title and selected place
        viewModel.title = "My Property"
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        
        // Then canSubmit should return true
        XCTAssertTrue(viewModel.canSubmit)
    }

    func testClearingFormResetsEverything() {
        // Given a filled form
        viewModel.title = "Test"
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        viewModel.price = "123"
        viewModel.description = "Property description test"
        
        // When clearing the form
        viewModel.clearForm()

        // Then all fields should reset
        XCTAssertEqual(viewModel.title, "")
        XCTAssertNil(viewModel.selectedPlace)
        XCTAssertTrue(viewModel.suggestions.isEmpty)
        XCTAssertEqual(viewModel.price, "")
        XCTAssertEqual(viewModel.description, "")
    }

    func testSelectedPlaceResetsWhenEditingText() {
        // Given a pre-selected place
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        
        let expectation = XCTestExpectation(description: "selectedPlace should reset after editing text")
        
        // Observe selectedPlace changes
        var observedChanges = 0
        viewModel.$selectedPlace
            .dropFirst() // Ignore initial value
            .sink { selectedPlace in
                observedChanges += 1
                if observedChanges == 1 {
                    XCTAssertNil(selectedPlace)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When user edits the text
        viewModel.locationText = "Athen"
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testSubmitReturnsProperJson() throws {
        // Given a fully filled form
        viewModel.title = "Test"
        let place = Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")
        viewModel.select(place: place)
        viewModel.price = "123"
        viewModel.description = "Property description test"

        // When submitting
        viewModel.submit()

        // Then: JSON sheet should show with correct data
        XCTAssertTrue(viewModel.showJSONSheet)

        let data = Data(viewModel.jsonResult.utf8)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        
        XCTAssertEqual(jsonObject?["title"] as? String, "Test")
        XCTAssertEqual(jsonObject?["price"] as? String, "123")
        XCTAssertEqual(jsonObject?["description"] as? String, "Property description test")
        
        // Validate nested location data
        if let location = jsonObject?["location"] as? [String: Any] {
            XCTAssertEqual(location["placeId"] as? String, "1")
            XCTAssertEqual(location["mainText"] as? String, "Athens")
            XCTAssertEqual(location["secondaryText"] as? String, "Greece")
        } else {
            XCTFail("Location is missing or invalid")
        }
    }
    
    func testFetchSuggestionsSavesToCache() throws {
        // Given mock API response data
        let mockPlaces = [Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")]
        let mockData = try JSONEncoder().encode(mockPlaces)
        
        let query = "Athens"
        let testURL = URL(string: "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws?input=\(query)")!
        URLProtocolMock.testURLs[testURL] = mockData
        
        let suggestionsExpectation = XCTestExpectation(description: "Should receive suggestions")
        let cacheExpectation = XCTestExpectation(description: "Should cache response")
        
        var suggestionsReceived = false
        
        // Observe suggestions changes
        viewModel.$suggestions
            .dropFirst()
            .sink { suggestions in
                if !suggestions.isEmpty && !suggestionsReceived {
                    suggestionsReceived = true
                    XCTAssertEqual(suggestions.count, 1)
                    XCTAssertEqual(suggestions.first?.mainText, "Athens")
                    suggestionsExpectation.fulfill()
                    
                    // After short delay, verify data is cached
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let request = URLRequest(url: testURL)
                        let cached = self.mockCache.cachedResponse(for: request)
                        XCTAssertNotNil(cached, "Response should be cached")
                        cacheExpectation.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        // When fetching suggestions
        viewModel.fetchSuggestions(for: "Athens")
        
        // Then both expectations should complete
        wait(for: [suggestionsExpectation, cacheExpectation], timeout: 3)
    }

    func testFetchSuggestionsLoadsFromCacheOnSecondCall() throws {
        // Given: pre-populated cache
        let mockPlaces = [Place(placeId: "1", mainText: "Athens", secondaryText: "Greece")]
        let mockData = try JSONEncoder().encode(mockPlaces)
        let query = "Athens"
        let testURL = URL(string: "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws?input=\(query)")!
        
        let request = URLRequest(url: testURL)
        let response = HTTPURLResponse(url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let cachedResponse = CachedURLResponse(response: response, data: mockData)
        mockCache.storeCachedResponse(cachedResponse, for: request)
        
        // When fetching again
        viewModel.fetchSuggestions(for: "Athens")
        
        // Then results should load immediately from cache (no network)
        XCTAssertEqual(viewModel.suggestions.count, 1)
        XCTAssertEqual(viewModel.suggestions.first?.mainText, "Athens")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading when using cache")
    }
    
    func testFetchSuggestionsHandlesNetworkError() {
        // Given: simulated network failure
        URLProtocolMock.error = NSError(domain: "NetworkError", code: -1, userInfo: nil)
        let errorExpectation = XCTestExpectation(description: "Should handle error")
        
        // Observe suggestions (should remain empty)
        viewModel.$suggestions
            .dropFirst()
            .sink { suggestions in
                if suggestions.isEmpty {
                    errorExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When fetching suggestions
        viewModel.fetchSuggestions(for: "Athens")
        
        // Then: error is handled gracefully
        wait(for: [errorExpectation], timeout: 2)
    }

    func testFetchSuggestionsHandlesInvalidURL() {
        let expectation = XCTestExpectation(description: "isLoading should become false")
        
        // Track loading state transitions
        var loadingStates: [Bool] = []
        viewModel.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                // Expect it to toggle true -> false
                if loadingStates.count >= 2 && isLoading == false {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When calling with empty input (invalid URL)
        viewModel.fetchSuggestions(for: "")
        
        wait(for: [expectation], timeout: 2)
        
        // Then: isLoading must reset to false
        XCTAssertFalse(viewModel.isLoading, "isLoading should be false after network failure")
    }
    
    func testLocationAutocompleteDoesNotFetchWhenUnfocused() {
        // Given: unfocused state
        let expectation = XCTestExpectation(description: "Should not fetch when unfocused")
        expectation.isInverted = true // We expect this NOT to be fulfilled
        
        // Prepare mock data just in case
        let query = "Ath"
        let testURL = URL(string: "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws?input=\(query)")!
        URLProtocolMock.testURLs[testURL] = Data()
        
        var receivedSuggestions = false
        
        // Observe suggestions
        viewModel.$suggestions
            .dropFirst()
            .sink { suggestions in
                if !suggestions.isEmpty {
                    receivedSuggestions = true
                    expectation.fulfill() // Should NOT happen
                }
            }
            .store(in: &cancellables)
        
        // When typing but not focused
        viewModel.isLocationFocused = false
        viewModel.locationText = "Ath"
        
        wait(for: [expectation], timeout: 0.5)
        
        // Then: no fetch should occur
        XCTAssertFalse(receivedSuggestions, "Should not have received suggestions when unfocused")
    }

    func testLocationAutocompleteDebouncesRequests() {
        // Given: debouncing logic (300ms delay)
        let expectation = XCTestExpectation(description: "Should only fetch once after debounce")
        var fetchCount = 0
        
        // Observe suggestions
        viewModel.$suggestions
            .dropFirst()
            .sink { _ in
                fetchCount += 1
                if fetchCount == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When typing rapidly — only last input should trigger fetch
        viewModel.isLocationFocused = true
        viewModel.locationText = "A"
        viewModel.locationText = "At"
        viewModel.locationText = "Ath"
        
        // Then: only one fetch should occur after debounce period
        wait(for: [expectation], timeout: 1)
    }
}
