import Foundation

final class URLProtocolMock: URLProtocol {
    static var testURLs = [URL: Data]()
    static var error: Error?
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        
        // Match any URL that contains the lambda URL base
        let canInit = url.absoluteString.contains("oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws")
        print("URLProtocolMock canInit: \(url.absoluteString) -> \(canInit)")
        return canInit
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let url = request.url else {
            let error = NSError(domain: "URLProtocolMock", code: -1, userInfo: [NSLocalizedDescriptionKey: "No URL in request"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        print("URLProtocolMock startLoading for: \(url.absoluteString)")
        
        // Check if we should return an error
        if let error = URLProtocolMock.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        // Try to find matching URL - use the first one that matches the base
        let matchingURL = URLProtocolMock.testURLs.keys.first { testURL in
            testURL.absoluteString.contains("oapaiqtgkr6wfbum252tswprwa0ausnb.lambda-url.eu-central-1.on.aws")
        }
        
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
        
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        print("URLProtocolMock stopLoading")
    }
}
