import SwiftUI

struct HomeView: View {
    private let templateCount = TemplateLibrary.shared.templates.count

    var body: some View {
        NavigationStack {
            List {
                Section("Phase 0 · Foundation") {
                    NavigationLink {
                        TracingView()
                    } label: {
                        MenuRow(
                            title: "Write letters",
                            detail: "Learn, Practice and Test, scored by the shared engine",
                            symbol: "pencil.tip"
                        )
                    }
                    NavigationLink {
                        RecorderView()
                    } label: {
                        MenuRow(
                            title: "Recorder",
                            detail: "Milestone 2: record letter templates and handwriting samples",
                            symbol: "record.circle"
                        )
                    }
                }
                Section("This build") {
                    LabeledContent("Version", value: "Phase 0 · 0.2")
                    LabeledContent("Letter templates", value: "\(templateCount) loaded")
                }
            }
            .navigationTitle("Penwise")
        }
    }
}

private struct MenuRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
        .padding(.vertical, 4)
    }
}
