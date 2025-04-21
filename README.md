# PasskeyAuth

A Swift package that provides a simple way to implement passkey authentication in your iOS and macOS applications.

## Requirements

- iOS 16.0+ / macOS 13.0+
- Xcode 14.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add PasskeyAuth to your project using Swift Package Manager:

1. In Xcode, select your project in the Project Navigator
2. Select your target
3. Select the "Package Dependencies" tab
4. Click the "+" button
5. Enter the repository URL: `https://github.com/ephemeraHQ/PasskeyAuth.git`
6. Click "Add Package"

## Usage

### Configuration

First, create a `PasskeyConfiguration` instance with your server details:

```swift
// Basic configuration with default endpoints
let configuration = PasskeyConfiguration(
    baseURL: URL(string: "https://your-server.com")!,
    rpID: "your-server.com"
)

// Configuration with custom endpoint paths
let configuration = PasskeyConfiguration(
    baseURL: URL(string: "https://your-server.com")!,
    rpID: "your-server.com",
    endpoints: PasskeyEndpoints(
        registerChallenge: "/api/v1/auth/register-challenge",
        loginChallenge: "/api/v1/auth/login-challenge",
        registerPasskey: "/api/v1/auth/register",
        loginPasskey: "/api/v1/auth/login"
    )
)

// Configuration with custom base path for endpoints
let configuration = PasskeyConfiguration(
    baseURL: URL(string: "https://your-server.com")!,
    rpID: "your-server.com",
    endpoints: PasskeyEndpoints(basePath: "/api/v1/auth")
)

// Configuration with certificate pinning
let configuration = PasskeyConfiguration(
    baseURL: URL(string: "https://your-server.com")!,
    rpID: "your-server.com",
    pinnedCertificates: [certificateData] // Add your server's certificate data
)
```

### Initialize PasskeyAuth

Create a presentation context provider that conforms to `PasskeyPresentationContextProvider`:

```swift
class MyPresentationContextProvider: PasskeyPresentationContextProvider {
    let presentationAnchor: ASPresentationAnchor
    
    init(window: UIWindow) {
        self.presentationAnchor = window
    }
}
```

Then create a `PasskeyAuth` instance with your configuration.

```swift
let presentationProvider = MyPresentationContextProvider(window: window)
let passkeyAuth = PasskeyAuth(
    configuration: configuration,
    logger: PasskeyAuthLogger.Logger.shared // Optional: Provide a custom logger
)
```

For SwiftUI apps, you can create a provider that uses the current window:

```swift
class SwiftUIPresentationContextProvider: PasskeyPresentationContextProvider {
    let presentationAnchor: ASPresentationAnchor
    
    init() {
        // Get the current window from the scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        self.presentationAnchor = window
    }
}
```

Set the presentation provider:

```swift
VStack {
    ...
}
.onAppear {
    PasskeyError.setDebugMode(true)
    
    Task { @MainActor in
        let presentationProvider = SwiftUIPresentationProvider()
        await passkeyAuth.setPresentationContextProvider(presentationProvider)
    }
}
```

### Register a Passkey

To register a new passkey:

```swift
Task {
    do {
        let response = try await passkeyAuth.registerPasskey(displayName: "My Passkey")
        if response.success {
            print("Passkey registered successfully")
            print("Token:", response.token)
        } else {
            print("Registration failed")
        }
    } catch {
        print("Failed to register passkey:", error.localizedDescription)
    }
}
```

### Login with Passkey

To login with a passkey:

```swift
Task {
    do {
        let response = try await passkeyAuth.loginWithPasskey()
        if response.success {
            print("Logged in successfully")
            print("Token:", response.token)
        } else {
            print("Login failed")
        }
    } catch {
        print("Failed to login:", error.localizedDescription)
    }
}
```

## Logging

PasskeyAuth includes a built-in logging system that helps with debugging and monitoring. The logger is configurable and production-safe:

```swift
// Get the shared logger instance
let logger = PasskeyAuthLogger.Logger.shared

// Configure minimum log level
logger.minimumLogLevel = .info // Only show info and above

// Use different log levels
logger.debug("Detailed debug information")
logger.info("General information")
logger.warning("Warning message")
logger.error("Error message")

// Create a production-safe logger
let productionLogger = PasskeyAuthLogger.Logger(isProduction: true)
```

The logger includes the following features:
- Different log levels (debug, info, warning, error)
- Configurable minimum log level
- Production mode that prevents logging sensitive data
- Timestamp and file information in log messages
- Emoji indicators for different log levels
- Debug-only logging by default

In production mode, the logger automatically filters out messages containing sensitive information like:
- Tokens
- Certificates
- Keys
- Passwords

Additional debug info can be included in errors with this option:

```swift
PasskeyError.setDebugMode(true) // should not be used in production
```

## Error Handling

The package provides a `PasskeyError` enum that covers common error cases:

- `invalidURL`: The URL is invalid
- `noData`: No data was received from the server
- `invalidChallenge`: The challenge received from the server is invalid
- `authenticationFailed`: The authentication failed
- `registrationFailed`: The registration failed
- `authenticationInProgress`: Another authentication attempt is already in progress
- `rateLimit`: The request was rate limited by the server
- `networkError`: Network connectivity error
- `serverError`: Server error with status code
- `jsonParsingError`: JSON parsing error
- `configurationError`: Configuration error

Each error case includes a user-friendly error description and recovery suggestion.

## Thread Safety

The `PasskeyAuth` class is implemented as an actor, ensuring thread safety for all operations. All public methods can be called from any thread, and UI-related operations are automatically dispatched to the main thread.

## Certificate Pinning

PasskeyAuth supports certificate pinning for enhanced security. You can provide your server's certificate data when creating the configuration:

```swift
// Load your server's certificate
guard let certificateURL = Bundle.main.url(forResource: "server", withExtension: "cer"),
      let certificateData = try? Data(contentsOf: certificateURL) else {
    fatalError("Failed to load certificate")
}

// Create configuration with certificate pinning
let configuration = PasskeyConfiguration(
    baseURL: URL(string: "https://your-server.com")!,
    rpID: "your-server.com",
    pinnedCertificates: [certificateData]
)
```

The package will verify that the server's certificate matches your pinned certificate during all network requests.

## Example App

The package includes an example app (`PasskeyAuthExample`) that demonstrates how to implement passkey authentication in a real iOS application. To run the example app:

1. Clone the repository
2. Create a `.env` file in the root directory with your configuration:
   ```
   API_BASE_URL=https://your-server.com
   RP_ID=your-server.com
   ```
3. Generate the required configuration files:
   ```bash
   make generate
   ```
   This will:
   - Generate `Secrets.swift` from your `.env` file
   - Generate the app site association entitlements file

The Makefile provides several useful commands:
- `make secrets`: Generate only the Secrets.swift file
- `make entitlements`: Generate only the entitlements file
- `make generate`: Generate all configuration files
- `make help`: Show all available commands

## License

PasskeyAuth is available under the MIT license. See the LICENSE file for more info. 
