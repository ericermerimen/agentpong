import Foundation

/// App version, read from the VERSION file at build time or hardcoded as fallback.
/// Updated by the build script (Scripts/build-app.sh) during release builds.
public enum AppVersion {
    public static let current = "1.2.1"

    /// Bundle version (available when running as .app, nil for plain binary)
    public static var bundleVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Best available version string
    public static var display: String {
        bundleVersion ?? current
    }
}
