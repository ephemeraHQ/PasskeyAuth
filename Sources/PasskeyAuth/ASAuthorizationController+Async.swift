import AuthenticationServices
import Foundation

/// A response type that encapsulates the result of an authorization request
public enum ASAuthorizationResponse {
    case registration(ASAuthorizationPlatformPublicKeyCredentialRegistration)
    case assertion(ASAuthorizationPlatformPublicKeyCredentialAssertion)
}

extension ASAuthorizationController {
    /// Performs authorization requests asynchronously
    /// - Parameter requests: The authorization requests to perform
    /// - Returns: An ASAuthorizationResponse containing the result of the authorization
    /// - Throws: ASAuthorizationError if the authorization fails
    public func performRequestsAsync() async throws -> ASAuthorizationResponse {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let delegate = AsyncAuthorizationDelegate { result in
                    continuation.resume(with: result)
                }
                
                // Store the delegate as an associated object to prevent it from being deallocated
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.delegateKey,
                    delegate,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                
                self.delegate = delegate
                self.performRequests()
            }
        }
    }
}

@MainActor
private final class AsyncAuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Result<ASAuthorizationResponse, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorizationResponse, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let registration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            completion(.success(.registration(registration)))
        } else if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            completion(.success(.assertion(assertion)))
        } else {
            completion(.failure(ASAuthorizationError(.failed)))
        }
    }
    
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        completion(.failure(error))
    }
}

private enum AssociatedKeys {
    static var delegateKey = "AsyncAuthorizationDelegateKey"
} 
