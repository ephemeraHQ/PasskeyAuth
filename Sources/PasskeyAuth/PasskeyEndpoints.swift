import Foundation

/// Configuration for authentication endpoints
public struct PasskeyEndpoints {
    /// The registration challenge endpoint
    public let registerChallenge: String
    
    /// The login challenge endpoint
    public let loginChallenge: String
    
    /// The passkey registration endpoint
    public let registerPasskey: String
    
    /// The passkey login endpoint
    public let loginPasskey: String
    
    /// Creates a new PasskeyEndpoints instance with default paths
    /// - Parameter basePath: The base path for all endpoints (defaults to "/auth")
    public init(basePath: String = "/auth") {
        self.registerChallenge = "\(basePath)/challenge/register"
        self.loginChallenge = "\(basePath)/challenge/login"
        self.registerPasskey = "\(basePath)/register-passkey"
        self.loginPasskey = "\(basePath)/login-passkey"
    }
    
    /// Creates a new PasskeyEndpoints instance with custom paths
    /// - Parameters:
    ///   - registerChallenge: The registration challenge endpoint
    ///   - loginChallenge: The login challenge endpoint
    ///   - registerPasskey: The passkey registration endpoint
    ///   - loginPasskey: The passkey login endpoint
    public init(
        registerChallenge: String,
        loginChallenge: String,
        registerPasskey: String,
        loginPasskey: String
    ) {
        self.registerChallenge = registerChallenge
        self.loginChallenge = loginChallenge
        self.registerPasskey = registerPasskey
        self.loginPasskey = loginPasskey
    }
} 