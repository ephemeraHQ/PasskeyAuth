//
//  ContentView.swift
//  PrivyExampleApp
//
//  Created by Jarod Luebbert on 4/18/25.
//

import SwiftUI
import PasskeyAuth
import AuthenticationServices

// Create a presentation provider that uses the current window
@objc
final class SwiftUIPresentationProvider: NSObject, PasskeyPresentationContextProvider {
    let presentationAnchor: ASPresentationAnchor
    
    override init() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        self.presentationAnchor = window
        super.init()
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        self.presentationAnchor
    }
}

struct ContentView: View {
    @State private var displayName: String = ""
    @State private var isRegistered: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var message = "Welcome to PasskeyAuth Example"
    @State private var isRegistering = false
    @State private var isLoggingIn = false
    private let logger = PasskeyAuthLogger.Logger.shared
    
    // Use an enum to represent the initialization state
    private enum AuthState {
        case uninitialized
        case initialized(PasskeyAuth)
        case error(String)
    }
    
    @State private var authState: AuthState = .uninitialized
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()
                
                switch authState {
                case .uninitialized:
                    ProgressView("Initializing...")
                        .onAppear {
                            initializeAuth()
                        }
                case .error(let error):
                    VStack {
                        Text("Failed to initialize authentication")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            initializeAuth()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                case .initialized(let passkeyAuth):
                    authContent(passkeyAuth: passkeyAuth)
                }
            }
            .navigationTitle("PasskeyAuth Example")
            .disabled(isLoading)
        }
    }
    
    private func authContent(passkeyAuth: PasskeyAuth) -> some View {
        VStack(spacing: 20) {
            if !isRegistered {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    isRegistering = true
                    register(passkeyAuth: passkeyAuth)
                }) {
                    Text("Register Passkey")
                        .padding()
                }
                .tint(.white)
                .padding(.horizontal)
                .buttonStyle(.borderless)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12.0))
                .disabled(isRegistering || isLoggingIn || displayName.isEmpty)
            }
            
            Button(action: {
                isLoggingIn = true
                login(passkeyAuth: passkeyAuth)
            }) {
                Text("Login with Passkey")
                    .padding()
            }
            .padding(.horizontal)
            .background(Color.green)
            .tint(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12.0))
            .disabled(isRegistering || isLoggingIn)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if isLoading {
                ProgressView()
            }
        }
        .onAppear {
            PasskeyError.setDebugMode(true)
            
            Task { @MainActor in
                let presentationProvider = SwiftUIPresentationProvider()
                await passkeyAuth.setPresentationContextProvider(presentationProvider)
            }
        }
    }
    
    private func initializeAuth() {
        isLoading = true
        errorMessage = nil
        
        do {
            let configuration = try PasskeyConfiguration(
                baseURL: URL(string: Secrets.API_BASE_URL)!,
                rpID: Secrets.RP_ID
            )
            
            let passkeyAuth = PasskeyAuth(configuration: configuration)
            authState = .initialized(passkeyAuth)
        } catch {
            logger.error("Configuration error: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func register(passkeyAuth: PasskeyAuth) {
        guard !displayName.isEmpty else {
            isRegistering = false
            errorMessage = "Please enter a display name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let (registration, response) = try await passkeyAuth.registerPasskey(displayName: displayName)
                logger.info("Registration Success:")
                logger.debug("Success: \(response.success)")
                logger.debug("Registration: \(registration)")
                logger.debug("Token: \(response.token)")
                isRegistered = true
                errorMessage = "Registration successful!"
            } catch {
                logger.error("Registration Error: \(error.localizedDescription)")
                errorMessage = "Registration failed: \(error.localizedDescription)"
            }
            isLoading = false
            isRegistering = false
        }
    }
    
    private func login(passkeyAuth: PasskeyAuth) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let (assertion, response) = try await passkeyAuth.loginWithPasskey()
                logger.info("Login Success:")
                logger.debug("Assertion: \(assertion)")
                logger.debug("Success: \(response.success)")
                logger.debug("Token: \(response.token)")
                errorMessage = "Login successful!"
            } catch {
                logger.error("Login Error: \(error.localizedDescription)")
                errorMessage = "Login failed: \(error.localizedDescription)"
            }
            isLoading = false
            isLoggingIn = false
        }
    }
}

#Preview {
    ContentView()
}
