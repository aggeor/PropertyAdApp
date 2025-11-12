import Foundation
import Combine

final class AdFormViewModel: ObservableObject {
    @Published var title = ""
    @Published var locationText = ""
    @Published var price = ""
    @Published var description = ""

    @Published var suggestions: [Place] = []
    @Published var selectedPlace: Place? = nil
    @Published var isLoading = false

    @Published var showJSONSheet = false
    @Published var jsonResult = ""

    var cancellables = Set<AnyCancellable>()

    var canSubmit: Bool {
        !title.isEmpty && selectedPlace != nil
    }

    func select(place: Place) {
        selectedPlace = place
        locationText = "\(place.mainText), \(place.secondaryText)"
        suggestions = []
    }

    func submit() {
        guard let place = selectedPlace else { return }

        let property = [
            "title": title,
            "location": [
                "placeId": place.placeId,
                "mainText": place.mainText,
                "secondaryText": place.secondaryText
            ],
            "price": price,
            "description": description
        ] as [String: Any]

        if let data = try? JSONSerialization.data(withJSONObject: property, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            jsonResult = jsonString
            showJSONSheet = true
            clearForm()
        }
    }

    func clearForm() {
        title = ""
        locationText = ""
        price = ""
        description = ""
        selectedPlace = nil
        suggestions = []
    }
}
