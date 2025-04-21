import Foundation
import AuthenticationServices
import CryptoKit

private final class PasskeyAuthDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let passkeyAuth: PasskeyAuth
    var continuation: CheckedContinuation<PasskeyResponse, Error>?
    
    init(passkeyAuth: PasskeyAuth) {
        self.passkeyAuth = passkeyAuth
        super.init()
    }
    
    func setContinuation(_ continuation: CheckedContinuation<PasskeyResponse, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            if let registration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
                guard let rawAttestationObject = registration.rawAttestationObject else {
                    continuation?.resume(throwing: PasskeyError.registrationFailed("Missing attestation object"))
                    continuation = nil
                    return
                }
                
                do {
                    try await passkeyAuth.postRegisterData(
                        credentialID: registration.credentialID,
                        attestationObject: rawAttestationObject,
                        clientDataJSON: registration.rawClientDataJSON
                    )
                } catch {
                    continuation?.resume(throwing: error)
                    continuation = nil
                }
            } else if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                do {
                    try await passkeyAuth.postLoginData(
                        credentialID: assertion.credentialID,
                        authenticatorData: assertion.rawAuthenticatorData,
                        clientDataJSON: assertion.rawClientDataJSON,
                        signature: assertion.signature
                    )
                } catch {
                    continuation?.resume(throwing: error)
                    continuation = nil
                }
            }
        }
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            await passkeyAuth.setAuthenticating(false)
            continuation?.resume(throwing: PasskeyError.authenticationFailed(error.localizedDescription))
            continuation = nil
        }
    }
}

/// A class that handles passkey authentication
/// - Thread Safety: This class is thread-safe through the use of Swift's actor system.
///   All public methods can be called from any thread, and UI-related operations are automatically
///   dispatched to the main thread.
public actor PasskeyAuth {
    private let configuration: PasskeyConfiguration
    private let session: URLSession
    private var isAuthenticating: Bool = false
    /// The presentation context provider for the passkey authentication
    private var presentationContextProvider: PasskeyPresentationContextProvider?
    private var delegate: PasskeyAuthDelegate?
    private let certificatePinningDelegate: CertificatePinningDelegate?
    private let logger: PasskeyAuthLogger.Logger
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 1.0 // Minimum 1 second between requests
    
    /// Creates a new PasskeyAuth instance
    /// - Parameter configuration: The configuration for the passkey authentication
    public init(
        configuration: PasskeyConfiguration,
        logger: PasskeyAuthLogger.Logger = .shared
    ) {
        self.configuration = configuration
        self.logger = logger
        
        let sessionConfig = configuration.urlSessionConfiguration ?? URLSessionConfiguration.default
        sessionConfig.urlCache = nil
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        if let pinnedCertificates = configuration.pinnedCertificates {
            logger.info("Setting up certificate pinning with \(pinnedCertificates.count) certificates")
            self.certificatePinningDelegate = CertificatePinningDelegate(pinnedCertificates: pinnedCertificates, logger: logger)
            self.session = URLSession(
                configuration: sessionConfig,
                delegate: certificatePinningDelegate,
                delegateQueue: nil
            )
        } else {
            logger.warning("No certificates provided for pinning")
            self.certificatePinningDelegate = nil
            self.session = URLSession(configuration: sessionConfig)
        }
        
        // Validate configuration
        guard !configuration.baseURL.absoluteString.isEmpty else {
            fatalError("Base URL cannot be empty")
        }
        
        guard !configuration.rpID.isEmpty else {
            fatalError("RP ID cannot be empty")
        }
        
        self.delegate = PasskeyAuthDelegate(passkeyAuth: self)
    }
    
    /// Sets the presentation context provider for the passkey authentication
    /// - Parameter provider: The provider that will handle presenting the authentication UI
    public func setPresentationContextProvider(_ provider: PasskeyPresentationContextProvider) {
        self.presentationContextProvider = provider
    }
    
    /// Checks if enough time has passed since the last request
    /// - Throws: PasskeyError.rateLimit if requests are too frequent
    private func checkRateLimit() throws {
        guard let lastRequest = lastRequestTime else {
            lastRequestTime = Date()
            return
        }
        
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
        guard timeSinceLastRequest >= minimumRequestInterval else {
            throw PasskeyError.rateLimit(retryAfter: minimumRequestInterval - timeSinceLastRequest)
        }
        
        lastRequestTime = Date()
    }
    
    /// Registers a new passkey
    /// - Parameter displayName: The display name for the passkey
    /// - Returns: A PasskeyResponse containing the registration result
    /// - Throws: Various PasskeyError cases if registration fails
    public func registerPasskey(displayName: String) async throws -> PasskeyResponse {
        try checkRateLimit()
        
        guard let presentationContextProvider = presentationContextProvider else {
            throw PasskeyError.configurationError("Presentation context provider not set")
        }
        
        guard !isAuthenticating else {
            throw PasskeyError.authenticationInProgress
        }
        
        guard var urlComponents = URLComponents(string: "\(configuration.baseURL)\(configuration.endpoints.registerChallenge)") else {
            throw PasskeyError.invalidURL("Failed to create URL components for registration challenge")
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "displayName", value: displayName)
        ]
        
        guard let url = urlComponents.url else {
            throw PasskeyError.invalidURL("Failed to create URL from components")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyError.networkError(NSError(domain: "", code: -1))
        }
        
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw PasskeyError.rateLimit(retryAfter: retryAfter)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw PasskeyError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let challengeB64 = json?["challenge"] as? String else {
            throw PasskeyError.invalidChallenge("Challenge not found in response")
        }
        
        guard let challengeData = challengeB64.base64URLDecoded() else {
            throw PasskeyError.invalidChallenge("Failed to decode challenge")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                    relyingPartyIdentifier: self.configuration.rpID
                )
                
                let request = provider.createCredentialRegistrationRequest(
                    challenge: challengeData,
                    name: displayName,
                    userID: UUID().uuidString.data(using: .utf8)!
                )
                request.userVerificationPreference = self.configuration.userVerificationPreference
                
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = await self.delegate
                controller.presentationContextProvider = presentationContextProvider
                
                // Set up the continuation before setting isAuthenticating
                await self.delegate?.setContinuation(continuation)
                
                // Set authenticating state
                await self.setAuthenticating(true)
                controller.performRequests()
            }
        }
    }
    
    /// Logs in with a passkey
    /// - Returns: A PasskeyResponse containing the login result
    /// - Throws: Various PasskeyError cases if login fails
    public func loginWithPasskey() async throws -> PasskeyResponse {
        try checkRateLimit()
        
        guard let presentationContextProvider = presentationContextProvider else {
            throw PasskeyError.configurationError("Presentation context provider not set")
        }
        
        guard !isAuthenticating else {
            throw PasskeyError.authenticationInProgress
        }
        
        guard let url = URL(string: "\(configuration.baseURL)\(configuration.endpoints.loginChallenge)") else {
            throw PasskeyError.invalidURL("Failed to create URL for login challenge")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyError.networkError(NSError(domain: "", code: -1))
        }
        
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw PasskeyError.rateLimit(retryAfter: retryAfter)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw PasskeyError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let challengeB64 = json?["challenge"] as? String else {
            throw PasskeyError.invalidChallenge("Challenge not found in response")
        }
        
        guard let challengeData = challengeB64.base64URLDecoded() else {
            throw PasskeyError.invalidChallenge("Failed to decode challenge")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                    relyingPartyIdentifier: self.configuration.rpID
                )
                
                let request = provider.createCredentialAssertionRequest(challenge: challengeData)
                request.userVerificationPreference = self.configuration.userVerificationPreference
                
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = await self.delegate
                controller.presentationContextProvider = presentationContextProvider
                
                // Set up the continuation before setting isAuthenticating
                await self.delegate?.setContinuation(continuation)
                
                // Set authenticating state
                await self.setAuthenticating(true)
                controller.performRequests()
            }
        }
    }
    
    // MARK: - Private Methods
    
    fileprivate func setAuthenticating(_ value: Bool) {
        isAuthenticating = value
    }
    
    func postRegisterData(
        credentialID: Data,
        attestationObject: Data,
        clientDataJSON: Data
    ) async throws {
        defer { Task { await self.setAuthenticating(false) } }
        
        guard let url = URL(string: "\(configuration.baseURL)\(configuration.endpoints.registerPasskey)") else {
            throw PasskeyError.invalidURL("Failed to create URL for passkey registration")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "attestationResponse": [
                "id": credentialID.base64URLEncodedString(),
                "rawId": credentialID.base64URLEncodedString(),
                "type": "public-key",
                "response": [
                    "attestationObject": attestationObject.base64URLEncodedString(),
                    "clientDataJSON": clientDataJSON.base64URLEncodedString()
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyError.networkError(NSError(domain: "", code: -1))
        }
        
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw PasskeyError.rateLimit(retryAfter: retryAfter)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw PasskeyError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let passkeyResponse = try JSONDecoder().decode(PasskeyResponse.self, from: data)
        await self.delegate?.continuation?.resume(returning: passkeyResponse)
        await self.delegate?.continuation = nil
    }
    
    func postLoginData(
        credentialID: Data,
        authenticatorData: Data,
        clientDataJSON: Data,
        signature: Data
    ) async throws {
        defer { Task { await self.setAuthenticating(false) } }
        
        guard let url = URL(string: "\(configuration.baseURL)\(configuration.endpoints.loginPasskey)") else {
            throw PasskeyError.invalidURL("Failed to create URL for passkey login")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "authenticationResponse": [
                "id": credentialID.base64URLEncodedString(),
                "rawId": credentialID.base64URLEncodedString(),
                "type": "public-key",
                "response": [
                    "authenticatorData": authenticatorData.base64URLEncodedString(),
                    "clientDataJSON": clientDataJSON.base64URLEncodedString(),
                    "signature": signature.base64URLEncodedString(),
                    "userHandle": ""
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyError.networkError(NSError(domain: "", code: -1))
        }
        
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw PasskeyError.rateLimit(retryAfter: retryAfter)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw PasskeyError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
        
        let passkeyResponse = try JSONDecoder().decode(PasskeyResponse.self, from: data)
        await self.delegate?.continuation?.resume(returning: passkeyResponse)
        await self.delegate?.continuation = nil
    }
}
