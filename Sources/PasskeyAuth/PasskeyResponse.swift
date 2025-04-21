public struct PasskeyResponse: Codable {
    
    /// Whether the authentication was successful
    public let success: Bool
    
    /// The JWT token received from the server
    public let token: String
    
    /// Creates a new PasskeyResponse
    /// - Parameters:
    ///   - success: Whether the authentication was successful
    ///   - token: The JWT token received from the server
    public init(success: Bool, token: String) {
        self.success = success
        self.token = token
    }
}
