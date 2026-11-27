import SwiftUI

enum AppLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let subscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let support = URL(string: "mailto:penwise.dev@gmail.com")!
}

struct PrivacyPolicyView: View {
    private let sections = NSDataAsset(name: "PrivacyPolicy")
        .flatMap { String(data: $0.data, encoding: .utf8) }?
        .components(separatedBy: "\n\n") ?? []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections.filter { !$0.hasPrefix("# ") }, id: \.self) { paragraph in
                    if paragraph.hasPrefix("## ") {
                        Text(String(paragraph.dropFirst(3))).font(.workbook(.title2))
                            .accessibilityAddTraits(.isHeader)
                    } else {
                        Text((try? AttributedString(markdown: paragraph)) ?? AttributedString(paragraph))
                    }
                }
                Link("Read the policy on GitHub", destination: URL(string: "https://github.com/Panic-Push/handsome/blob/main/docs/privacy/index.md")!)
            }.padding(24).frame(maxWidth: 720)
        }.navigationTitle("Privacy policy")
    }
}
