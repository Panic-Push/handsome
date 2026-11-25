import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("penwise.account.appleUser") private var appleUser = ""
    @AppStorage("penwise.account.email") private var email = ""
    @AppStorage("penwise.account.name") private var displayName = ""
    @State private var accountMessage: String?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if appleUser.isEmpty {
                        SignInWithAppleButton(.signIn, onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        }, onCompletion: finishSignIn)
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: 360, minHeight: 48)
                    } else {
                        Label(displayName.isEmpty ? "Signed in with Apple" : displayName,
                              systemImage: "person.crop.circle.fill")
                        if !email.isEmpty { LabeledContent("Email", value: email) }
                        Button("Sign out", action: signOut)
                    }
                    if let accountMessage { Text(accountMessage).font(.footnote) }
                } header: {
                    Text("Apple account")
                } footer: {
                    Text("Writing history and course progress belong to this iPad. Signing out keeps them on this device.")
                }
                Section("Writing preferences") {
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
            .navigationTitle("Account")
            .onAppear(perform: refreshCredential)
            .onChange(of: scenePhase) { _, phase in if phase == .active { refreshCredential() } }
            .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in refreshCredential() }
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

    private func finishSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                accountMessage = "Apple could not confirm this account. Please try again."
                return
            }
            if appleUser != credential.user {
                email = ""
                displayName = ""
            }
            appleUser = credential.user
            if let address = credential.email { email = address }
            if let name = credential.fullName {
                let formatted = PersonNameComponentsFormatter().string(from: name)
                if !formatted.isEmpty { displayName = formatted }
            }
            accountMessage = nil
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                accountMessage = error.localizedDescription
            }
        }
    }

    private func refreshCredential() {
        let user = appleUser
        guard !user.isEmpty else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user) { state, error in
            DispatchQueue.main.async {
                guard appleUser == user, error == nil else { return }
                if state == .revoked || state == .notFound { signOut() }
            }
        }
    }

    private func signOut() {
        appleUser = ""
        email = ""
        displayName = ""
        accountMessage = nil
    }
}
