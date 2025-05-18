public struct PasskeyResponse: Codable {
    /// Whether the authentication was successful
    public let success: Bool
    
    /// The JWT token received from the server
    public let token: String

    /// The user's public key
    public let publicKey: String

    /// The user's userID
    public let userID: String
}
