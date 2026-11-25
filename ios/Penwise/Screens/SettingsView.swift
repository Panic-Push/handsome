import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Writing") {
                    Picker("Writing size", selection: $settings.size) {
                        ForEach(WritingSize.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("I write with my", selection: $settings.handedness) {
                        ForEach(Handedness.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Apple Pencil only (ignore palm and finger)", isOn: $settings.pencilOnly)
                }
                Section {
                    Toggle("Show ad placeholders", isOn: $settings.showAdPlaceholders)
                    NavigationLink("Recorder: templates and samples") { RecorderView() }
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("With ad placeholders off, the app behaves as if no ad is available and goes straight to a mode's letters.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    ProgressStore.shared.reset()
                    JourneyStore.shared.reset()
                }
            } message: {
                Text("Best scores, attempts, streak and journey progress will be cleared on this iPad.")
            }
        }
    }
}
