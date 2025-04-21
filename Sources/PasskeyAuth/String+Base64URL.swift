import Foundation

extension String {
    /// Decodes a base64URL encoded string to Data
    /// - Returns: The decoded Data, or nil if decoding fails
    func base64URLDecoded() -> Data? {
        // First try direct base64 decoding
        if let data = Data(base64Encoded: self) {
            return data
        }
        
        // If that fails, try converting from base64URL to base64
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        // Try decoding again
        if let data = Data(base64Encoded: base64) {
            return data
        }
        
        // Last resort: try direct base64URL decoding
        return Data(base64urlEncoded: self)
    }
    
    /// Encodes a string to base64URL format
    /// - Returns: The base64URL encoded string
    func base64URLEncoded() -> String {
        return self.data(using: .utf8)?
            .base64URLEncodedString() ?? ""
    }
} 