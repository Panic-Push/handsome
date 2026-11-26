import Foundation

/// Public web pages the app links to. The privacy policy and terms are in
/// docs/ and can be published with GitHub Pages (see docs/app-store/launch-checklist.md).
enum AppLinks {
    static let privacyPolicy = URL(string: "https://panic-push.github.io/handsome/privacy/")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let manageAppleID = URL(string: "https://appleid.apple.com/account/manage")!
}
