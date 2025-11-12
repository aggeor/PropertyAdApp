import XCTest
import Combine
@testable import PropertyAdApp

final class AdFormViewModelTests: XCTestCase {
    var viewModel: AdFormViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        viewModel = AdFormViewModel()
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        cancellables = nil
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
        
        // Set text to trigger the Combine pipeline
        viewModel.locationText = "Athen"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(self.viewModel.selectedPlace == nil)
            expectation.fulfill()
        }

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
}
