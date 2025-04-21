//
//  CertificatePinningDelegate.swift
//  PasskeyAuth
//
//  Created by Jarod Luebbert on 4/20/25.
//

import Foundation

/// A delegate that handles certificate pinning for URLSession
internal class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedCertificates: [Data]
    private let pinnedPublicKeys: [Data]
    private let logger: PasskeyAuthLogger.Logger
    
    init(pinnedCertificates: [Data], logger: PasskeyAuthLogger.Logger = .shared) {
        self.pinnedCertificates = pinnedCertificates
        self.logger = logger
        // Extract public keys from certificates
        self.pinnedPublicKeys = pinnedCertificates.compactMap { certificateData in
            guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData),
                  let publicKey = SecCertificateCopyKey(certificate) else {
                return nil
            }
            
            var error: Unmanaged<CFError>?
            guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
                return nil
            }
            
            return publicKeyData
        }
        super.init()
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        logger.debug("Certificate pinning delegate called for host: \(challenge.protectionSpace.host)")
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            logger.error("Failed to get server trust")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        var result: SecTrustResultType = .invalid
        let status = SecTrustEvaluate(serverTrust, &result)
        guard status == errSecSuccess,
              result == .proceed || result == .unspecified else {
            logger.error("Certificate chain validation failed with status: \(status)")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get the leaf certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            logger.error("Failed to get server certificate")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data
        logger.debug("Got server certificate: \(serverCertificateData.count) bytes")
        
        // Get the server's public key
        guard let serverPublicKey = SecCertificateCopyKey(serverCertificate) else {
            logger.error("Failed to get server public key from certificate")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        var error: Unmanaged<CFError>?
        guard let serverPublicKeyData = SecKeyCopyExternalRepresentation(serverPublicKey, &error) as Data? else {
            if let error = error?.takeRetainedValue() {
                logger.error("Failed to get server public key data: \(error)")
            } else {
                logger.error("Failed to get server public key data with unknown error")
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        logger.debug("Got server public key: \(serverPublicKeyData.count) bytes")
        
        // Check if the server certificate matches any of our pinned certificates
        if pinnedCertificates.contains(serverCertificateData) {
            logger.info("Certificate pinning successful (certificate match)")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        
        // Check if the server's public key matches any of our pinned public keys
        if pinnedPublicKeys.contains(serverPublicKeyData) {
            logger.info("Certificate pinning successful (public key match)")
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        
        logger.error("Certificate pinning failed - no matches found")
        logger.debug("Server certificate size: \(serverCertificateData.count) bytes")
        logger.debug("Server public key size: \(serverPublicKeyData.count) bytes")
        logger.debug("Number of pinned certificates: \(pinnedCertificates.count)")
        logger.debug("Number of pinned public keys: \(pinnedPublicKeys.count)")
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
