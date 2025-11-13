import Foundation

// Custom URLProtocol subclass that intercepts network requests for testing.
// It replaces real network calls with predefined responses or errors.
final class URLProtocolMock: URLProtocol {
    
    // Stores fake responses keyed by URL. Used to simulate API responses.
    static var testURLs = [URL: Data]()
    
    // Optional error to simulate network failure.
    static var error: Error?
    
    // Determines whether this protocol should handle a given request.
    // Returning `true` here means we’ll intercept that request.
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        
        // Here we only intercept requests targeting our API.
        let canInit = url.absoluteString.contains("oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws")
        print("URLProtocolMock canInit: \(url.absoluteString) -> \(canInit)")
        return canInit
    }
    
    // Returns the canonical version of the request (no modification here).
    // This is required by URLProtocol subclasses.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    // Called when a request starts loading.
    // Instead of performing a real network call, we decide what to return.
    override func startLoading() {
        guard let url = request.url else {
            // If the request somehow has no URL, return an error immediately.
            let error = NSError(domain: "URLProtocolMock", code: -1, userInfo: [NSLocalizedDescriptionKey: "No URL in request"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        print("URLProtocolMock startLoading for: \(url.absoluteString)")
        
        // If a test has set a global error, simulate a failed network call.
        if let error = URLProtocolMock.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        // Otherwise, try to find mock data for this URL.
        // We look for the first URL that matches our Lambda base URL.
        let matchingURL = URLProtocolMock.testURLs.keys.first { testURL in
            testURL.absoluteString.contains("oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws")
        }
        
        // If no matching data is found, simulate a “no data” network error.
        guard let matchingURL = matchingURL,
              let data = URLProtocolMock.testURLs[matchingURL] else {
            let error = NSError(
                domain: "URLProtocolMock",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No mock data for URL: \(url.absoluteString)"]
            )
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        // Build a fake HTTP response with a 200 OK status.
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        // Tell the URL loading system that the response has been received.
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        
        // Provide the mock data payload to the client.
        client?.urlProtocol(self, didLoad: data)
        
        // Signal that loading is complete.
        client?.urlProtocolDidFinishLoading(self)
    }
    
    // Called if the request is cancelled — we just log for visibility.
    override func stopLoading() {
        print("URLProtocolMock stopLoading")
    }
}
