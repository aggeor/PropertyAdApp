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
    @Published var isLocationFocused = false

    private var cancellables = Set<AnyCancellable>()
    private let apiURL = "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws"
    private var lastLocationText: String?

    var canSubmit: Bool {
        !title.isEmpty && selectedPlace != nil
    }
    
    private let urlSession: URLSession
    private let urlCache: URLCache
    
    init(urlSession: URLSession = .shared, urlCache: URLCache = .shared) {
        self.urlSession = urlSession
        self.urlCache = urlCache
        setupLocationAutocomplete()
    }

    func select(place: Place) {
        selectedPlace = place
        locationText = "\(place.mainText), \(place.secondaryText)"
        suggestions = []
        lastLocationText = locationText
    }

    func submit() {
        guard let place = selectedPlace else { return }

        let property: [String: Any] = [
            "title": title,
            "location": [
                "placeId": place.placeId,
                "mainText": place.mainText,
                "secondaryText": place.secondaryText
            ],
            "price": price,
            "description": description
        ]

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
        lastLocationText = nil
    }

    private func setupLocationAutocomplete() {
        $locationText
            .combineLatest($isLocationFocused)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text, isFocused in
                guard let self = self else { return }

                // Reset selectedPlace if user edits text
                if let selected = self.selectedPlace,
                   text != "\(selected.mainText), \(selected.secondaryText)" {
                    self.selectedPlace = nil
                }

                // Clear lastQueryText if text < 3 or unfocused
                if text.count < 3 || !isFocused {
                    self.suggestions = []
                    self.lastLocationText = nil
                    return
                }

                // Only fetch if user is focused and text changed
                if isFocused, text != self.lastLocationText, text != self.selectedPlaceText {
                    self.fetchSuggestions(for: text)
                }
            }
            .store(in: &cancellables)
    }

    private var selectedPlaceText: String? {
        guard let place = selectedPlace else { return nil }
        return "\(place.mainText), \(place.secondaryText)"
    }

    func fetchSuggestions(for query: String) {
        lastLocationText = query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(apiURL)?input=\(encodedQuery)") else {
                isLoading = false
                return
        }

        let request = URLRequest(url: url)
        
        // Check memory cache first
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let places = try? JSONDecoder().decode([Place].self, from: cachedResponse.data) {
            self.suggestions = places
            isLoading = false // Make sure loading is false when using cache
            print("Loaded \(places.count) places from cache")
            return
        }

        isLoading = true

        urlSession.dataTaskPublisher(for: url)
            .map { [weak self] (data, response) -> (Data, URLResponse) in
                // Save to cache
                print("saving to cache")
                let cachedResponse = CachedURLResponse(response: response, data: data)
                self?.urlCache.storeCachedResponse(cachedResponse, for: URLRequest(url: url))
                return (data, response)
            }
            .map(\.0)
            .decode(type: [Place].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("Error fetching suggestions: \(error)")
                    self?.suggestions = []
                }
            } receiveValue: { [weak self] places in
                self?.suggestions = places
            }
            .store(in: &cancellables)
    }

}
