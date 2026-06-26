import APNSCore
import Foundation
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

enum APNSUrlSessionClientError: Error {
    case urlResponseNotFound
}

public struct APNSURLSessionClient: APNSClientProtocol {
    
    private let configuration: APNSURLSessionClientConfiguration
    
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    public init(configuration: APNSURLSessionClientConfiguration) {
        self.configuration = configuration
    }
    
    public func send(
        _ request: APNSRequest<some APNSMessage>
    ) async throws -> APNSResponse {
        
        /// Construct URL
        var urlRequest = URLRequest(url: URL(string: configuration.environment.absoluteURL + "/\(request.deviceToken)")!)
        urlRequest.httpMethod = "POST"
        /// Set headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (header, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }
        
        await urlRequest.setValue(try configuration.nextValidToken(), forHTTPHeaderField: "Authorization")
        
        /// Set Body
        urlRequest.httpBody = try encoder.encode(request.message)
    
        /// Make request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        /// Unwrap response
        guard let response = response as? HTTPURLResponse else {
            throw APNSUrlSessionClientError.urlResponseNotFound
        }

        /// `value(forHTTPHeaderField:)` performs a case-insensitive lookup, and the
        /// `apns-id` header may be absent (e.g. on some error responses), so it is optional.
        let apnsID = response.value(forHTTPHeaderField: "apns-id").flatMap { UUID(uuidString: $0) }
        let apnsUniqueID = response.value(forHTTPHeaderField: "apns-unique-id").flatMap { UUID(uuidString: $0) }

        /// Success/failure is determined by the HTTP status code, per Apple's APNs spec:
        /// a `200` is a successful delivery; anything else carries an error reason in the body.
        if response.statusCode == 200 {
            return APNSResponse(apnsID: apnsID, apnsUniqueID: apnsUniqueID)
        }

        /// Non-200: decode the error body when present, otherwise surface the status code alone.
        let errorResponse = try? decoder.decode(APNSErrorResponse.self, from: data)
        throw APNSError(
            responseStatus: response.statusCode,
            apnsID: apnsID,
            apnsUniqueID: apnsUniqueID,
            apnsResponse: errorResponse,
            timestamp: errorResponse?.timestampInSeconds.flatMap { Date(timeIntervalSince1970: $0) }
        )
    }

    public func shutdown() async throws {
        // no op
    }
}

#endif
