import Foundation
import AuthenticationServices

/// Configuration for PasskeyAuth
public struct PasskeyConfiguration {
    /// The base URL for the authentication server
    public let baseURL: URL
    
    /// The Relying Party ID (RP ID) for WebAuthn
    public let rpID: String
    
    /// Optional URLSession configuration
    public let urlSessionConfiguration: URLSessionConfiguration?
    
    /// The authentication endpoints configuration
    public let endpoints: PasskeyEndpoints
    
    /// Optional array of certificate data to pin. If provided, only connections
    /// to servers with matching certificates will be accepted.
    public let pinnedCertificates: [Data]?
    
    /// The user verification preference for passkey authentication.
    /// Defaults to .required for maximum security.
    public let userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
    
    /// Creates a new PasskeyConfiguration
    /// - Parameters:
    ///   - baseURL: The base URL for the authentication server
    ///   - rpID: The Relying Party ID (RP ID) for WebAuthn
    ///   - urlSessionConfiguration: Optional URLSession configuration
    ///   - endpoints: Optional endpoints configuration (defaults to standard paths)
    ///   - pinnedCertificates: Optional array of certificate data to pin
    ///   - userVerificationPreference: The user verification preference for passkey authentication (defaults to .required)
    /// - Throws: PasskeyError.configurationError if the URL is invalid
    public init(
        baseURL: URL,
        rpID: String,
        urlSessionConfiguration: URLSessionConfiguration? = nil,
        endpoints: PasskeyEndpoints? = nil,
        pinnedCertificates: [Data]? = nil,
        userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference = .required
    ) throws {
        // Validate URL
        guard baseURL.scheme?.lowercased() == "https" else {
            throw PasskeyError.configurationError("Base URL must use HTTPS")
        }
        
        guard let host = baseURL.host, !host.isEmpty else {
            throw PasskeyError.configurationError("Base URL must have a valid host")
        }
        
        // Check for path traversal attempts
        let path = baseURL.path
        if path.contains("..") || path.contains("//") {
            throw PasskeyError.configurationError("Base URL contains invalid path components")
        }
        
        self.baseURL = baseURL
        self.rpID = rpID
        self.urlSessionConfiguration = urlSessionConfiguration
        self.endpoints = endpoints ?? PasskeyEndpoints()
        self.pinnedCertificates = pinnedCertificates
        self.userVerificationPreference = userVerificationPreference
    }
} 
