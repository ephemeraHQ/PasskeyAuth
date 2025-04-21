//
//  PasskeyAuthTests.swift
//  
//
//  Created by Jarod Luebbert on 4/18/25.
//

import XCTest
@testable import PasskeyAuth

final class PasskeyAuthTests: XCTestCase {
    func testExample() throws {
        // This is an example test case
        XCTAssertTrue(true)
    }
    
    func testBase64URLEncoding() throws {
        let originalString = "Hello, World!"
        let data = originalString.data(using: .utf8)!
        let base64URLString = data.base64URLEncodedString()
        
        // Test encoding
        XCTAssertEqual(base64URLString, "SGVsbG8sIFdvcmxkIQ")
        
        // Test decoding
        let decodedData = Data(base64urlEncoded: base64URLString)
        XCTAssertNotNil(decodedData)
        let decodedString = String(data: decodedData!, encoding: .utf8)
        XCTAssertEqual(decodedString, originalString)
    }
}
