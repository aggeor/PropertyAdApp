import Foundation
import Combine

final class AdFormViewModel: ObservableObject {
    // MARK: - Published Properties
    // These trigger UI updates automatically when changed
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

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let apiURL = "https://oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws"
    private var lastLocationText: String?

    // MARK: - Dependencies
    private let urlSession: URLSession
    private let urlCache: URLCache

    // MARK: - Computed Properties
    var canSubmit: Bool {
        !title.isEmpty && selectedPlace != nil
    }

    // MARK: - Initialization
    init(urlSession: URLSession = .shared, urlCache: URLCache = .shared) {
        self.urlSession = urlSession
        self.urlCache = urlCache
        setupLocationAutocomplete()
    }

    // MARK: - User Actions
    /// Called when the user selects a suggested place from the list
    func select(place: Place) {
        selectedPlace = place
        locationText = "\(place.mainText), \(place.secondaryText)"
        suggestions = []
        lastLocationText = locationText
    }

    /// Creates and formats the JSON payload when user submits the form
    func submit() {
        guard let place = selectedPlace else { return }

        // Prepare property dictionary for serialization
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

        // Serialize to JSON and display in sheet
        if let data = try? JSONSerialization.data(withJSONObject: property, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            jsonResult = jsonString
            showJSONSheet = true
            clearForm()
        }
    }

    /// Resets all form fields
    func clearForm() {
        title = ""
        locationText = ""
        price = ""
        description = ""
        selectedPlace = nil
        suggestions = []
        lastLocationText = nil
    }

    // MARK: - Combine Logic
    /// Sets up the autocomplete logic using Combine publishers
    private func setupLocationAutocomplete() {
        $locationText
            .combineLatest($isLocationFocused)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // avoid frequent API calls
            .sink { [weak self] text, isFocused in
                guard let self = self else { return }

                // Reset selected place if user starts typing again
                if let selected = self.selectedPlace,
                   text != "\(selected.mainText), \(selected.secondaryText)" {
                    self.selectedPlace = nil
                }

                // Clear if text too short or user unfocused
                if text.count < 3 || !isFocused {
                    self.suggestions = []
                    self.lastLocationText = nil
                    return
                }

                // Only fetch if focused and text actually changed
                if isFocused, text != self.lastLocationText, text != self.selectedPlaceText {
                    self.fetchSuggestions(for: text)
                }
            }
            .store(in: &cancellables)
    }

    /// Convenience property to get full formatted text of selected place
    private var selectedPlaceText: String? {
        guard let place = selectedPlace else { return nil }
        return "\(place.mainText), \(place.secondaryText)"
    }

    // MARK: - Networking and Caching
    /// Fetches location suggestions either from cache or network
    func fetchSuggestions(for query: String) {
        lastLocationText = query
        
        // Construct request URL safely
        guard let url = URL(string: "\(apiURL)?input=\(query)") else {
            isLoading = false
            return
        }

        let request = URLRequest(url: url)
        
        // First: Check if we already have a cached response
        if let cachedResponse = urlCache.cachedResponse(for: request),
           let places = try? JSONDecoder().decode([Place].self, from: cachedResponse.data) {
            self.suggestions = places
            isLoading = false
            print("Loaded \(places.count) places from cache")
            return
        }

        // Otherwise, fetch from network
        isLoading = true

        urlSession.dataTaskPublisher(for: url)
            // Intercept the response to store it in cache
            .map { [weak self] (data, response) -> (Data, URLResponse) in
                print("Saving network response to cache")
                let cachedResponse = CachedURLResponse(response: response, data: data)
                self?.urlCache.storeCachedResponse(cachedResponse, for: request)
                return (data, response)
            }
            // Decode the data into an array of `Place`
            .map(\.0)
            .decode(type: [Place].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            // Handle completion and errors
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    print("Error fetching suggestions: \(error)")
                    self?.suggestions = []
                }
            } receiveValue: { [weak self] places in
                // Assign decoded places to published property
                self?.suggestions = places
            }
            .store(in: &cancellables)
    }
}
