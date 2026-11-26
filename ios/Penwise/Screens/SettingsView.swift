import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var showPaywall = false
    @ObservedObject private var store = StoreService.shared
    @ObservedObject private var ads = AdsService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image("FoxMark").resizable().frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 15)).accessibilityHidden(true)
                        Text("Your Penwise account").font(.workbook(.title2))
                    }
                    AppleAccountControls()
                } header: {
                    Text("Apple account")
                } footer: {
                    Text("Writing history and course progress belong to this iPad. Signing out keeps them on this device.")
                }
                Section("Premium") {
                    if store.isPremium {
                        Label("Premium is active", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        Button("Get Penwise Premium") { showPaywall = true }
                    }
                    Button("Restore purchases") { Task { await store.restore() } }
                }
                Section {
                    Picker("Age", selection: $settings.ageBand) {
                        ForEach(AgeBand.allCases.filter { $0 != .unknown }) { Text($0.title).tag($0) }
                        if settings.ageBand == .unknown { Text(AgeBand.unknown.title).tag(AgeBand.unknown) }
                    }
                    if ads.privacyOptionsRequired {
                        Button("Privacy choices for ads") { Task { await ads.showPrivacyOptions() } }
                    }
                    Link("Privacy policy", destination: AppLinks.privacyPolicy)
                    Button("Delete all my data", role: .destructive) { confirmDelete = true }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Your handwriting and progress stay on this iPad. Under 18s never see personalised ads.")
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { NavigationStack { PaywallView() } }
            .confirmationDialog("Delete all your data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    AccountService.deleteAllData()
                }
            } message: {
                Text("Your progress, plan, reports, settings and sign-in details will be erased from this iPad. Purchases can be restored later. To also stop using Sign in with Apple, visit appleid.apple.com.")
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

struct AppleAccountControls: View {
    var onSignIn: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("penwise.account.appleUser") private var appleUser = ""
    @AppStorage("penwise.account.email") private var email = ""
    @AppStorage("penwise.account.name") private var displayName = ""
    @State private var accountMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appleUser.isEmpty {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                }, onCompletion: finishSignIn)
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .frame(maxWidth: 360)
                .frame(height: 50)
            } else {
                Label(displayName.isEmpty ? "Signed in with Apple" : displayName,
                      systemImage: "person.crop.circle.fill")
                if !email.isEmpty { LabeledContent("Email", value: email) }
                Button("Sign out", action: signOut)
                Link("Manage Apple sign-in", destination: AppLinks.manageAppleID)
            }
            if let accountMessage { Text(accountMessage).font(.footnote) }
        }
        .onAppear(perform: refreshCredential)
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshCredential() } }
        .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in refreshCredential() }
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
            onSignIn()
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
