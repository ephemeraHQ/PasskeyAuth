#!/bin/bash

# Function to install SwiftLint
install_swiftlint() {
    echo "Installing SwiftLint..."
    
    # Remove any existing installation
    brew uninstall --force swiftlint sourcekitten 2>/dev/null || true
    
    # Clean Homebrew cache
    brew cleanup
    
    # Install SwiftLint with specific version
    brew install swiftlint@0.54.0
    
    # Verify installation
    if ! command -v swiftlint &> /dev/null; then
        echo "Failed to install SwiftLint"
        exit 1
    fi
}

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    install_swiftlint
fi

# Check SwiftLint version
SWIFTLINT_VERSION=$(swiftlint version)
echo "Using SwiftLint version: $SWIFTLINT_VERSION"

# Run SwiftLint with error handling
echo "Running SwiftLint..."
if ! swiftlint lint --reporter xcode; then
    if [[ $? -eq 134 ]]; then
        echo "SwiftLint crashed. Attempting to reinstall..."
        install_swiftlint
        echo "Running SwiftLint again..."
        if ! swiftlint lint --reporter xcode; then
            echo "SwiftLint still failed after reinstallation"
            exit 1
        fi
    else
        echo "SwiftLint found issues that need to be fixed."
        exit 1
    fi
fi

echo "SwiftLint completed successfully!"
exit 0 