import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var plans = PlanStore.shared
    @ObservedObject private var journeys = JourneyStore.shared
    @ObservedObject private var store = StoreService.shared
    @ObservedObject private var ads = AdsService.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("penwise.workbook.label") private var workbookName = ""
    @AppStorage("penwise.appearance") private var appearance = "System"
    @AppStorage("penwise.intention") private var intention = "Everyday notes"
    @AppStorage("penwise.experience") private var experience = "Starting out"
    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var showPaywall = false
    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image("FoxMark").resizable().frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 15)).accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(workbookName.isEmpty ? "My workbook" : workbookName).font(.workbook(.title2))
                            Text("Saved on this iPad").foregroundStyle(.secondary)
                        }
                    }
                    TextField("Workbook name", text: $workbookName)
                    LabeledContent("Writing goal", value: intention)
                    LabeledContent("Starting point", value: experience)
                }
                Section("Practice journal") {
                    LabeledContent("Day streak", value: String(progress.streak))
                    LabeledContent("Scored attempts today", value: String(progress.attemptsToday))
                    if let recent = progress.lastPlayed {
                        let attempts = progress.recentAttempts(recent.mode, recent.templateID)
                        if let last = attempts.first {
                            LabeledContent("Last score · \(TemplateLibrary.shared.template(id: recent.templateID)?.glyph ?? "writing")", value: "\(last.score)/100")
                        }
                    } else {
                        Text("Your first scored letter will appear here.").foregroundStyle(.secondary)
                    }
                    NavigationLink("Course milestones") {
                        List(LetterStyle.allCases) { style in
                            if let course = JourneyLibrary.shared.journey(style: style) {
                                let chapters = course.chapters.filter { !$0.isCheckpoint }
                                let completed = chapters.reduce(0) { $0 + journeys.completedCount($1, in: course) }
                                let total = chapters.reduce(0) { $0 + $1.letters.count }
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(style.title, systemImage: completed == total && total > 0 ? "rosette" : "book")
                                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                                    Text("\(completed) of \(total) letters completed").font(.footnote)
                                }.padding(.vertical, 6)
                            }
                        }.navigationTitle("Course milestones")
                    }
                }
                Section("Writing preferences") {
                    Picker("Daily goal", selection: $plans.minutesPerDay) {
                        ForEach(PlanStore.minuteChoices, id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    Picker("Appearance", selection: $appearance) {
                        ForEach(["System", "Light", "Dark"], id: \.self) { Text($0) }
                    }
                    Picker("Writing size", selection: $settings.size) {
                        ForEach(WritingSize.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("I write with my", selection: $settings.handedness) {
                        ForEach(Handedness.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Apple Pencil only", isOn: $settings.pencilOnly)
                    PracticeReminderRow()
                }
                Section("Premium") {
                    if store.isPremium {
                        Label("Premium is active", systemImage: "checkmark.seal.fill")
                        if let ends = store.trialEnds { LabeledContent("Trial ends", value: ends.formatted(date: .abbreviated, time: .omitted)) }
                        Link("Manage subscriptions", destination: AppLinks.subscriptions)
                    } else {
                        Button("Explore Penwise Premium") { showPaywall = true }
                    }
                    Button("Restore purchases") {
                        Task { await store.restore(); restoreMessage = store.lastError ?? (store.isPremium ? "Purchases restored." : "No active purchases found.") }
                    }
                    if let restoreMessage { Text(restoreMessage).font(.footnote) }
                }
                Section("Privacy and support") {
                    LabeledContent("Age group", value: settings.ageBand.title)
                    if ads.eligible && ads.privacyOptionsRequired {
                        Button("Privacy choices for ads") { Task { await ads.showPrivacyOptions() } }
                    }
                    NavigationLink("Privacy policy") { PrivacyPolicyView() }
                    Link("Terms of use", destination: AppLinks.terms)
                    Link("Contact Penwise", destination: AppLinks.support)
                    Button("Reset writing progress", role: .destructive) { confirmReset = true }
                    Button("Delete all my data", role: .destructive) { confirmDelete = true }
                }
                #if DEBUG
                Section("Developer") {
                    if ads.eligible { Toggle("Show ad placeholders", isOn: $settings.showAdPlaceholders) }
                    NavigationLink("Record templates and samples") { RecorderView() }
                }
                #endif
            }
            .navigationTitle("My workbook")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showPaywall) { NavigationStack { PaywallView() } }
            .confirmationDialog("Delete all workbook data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    dismiss()
                    AccountService.deleteAllData()
                }
            } message: {
                Text("This erases your samples, reports, reminders and settings from this iPad. Apple manages purchases and subscriptions separately.")
            }
            .confirmationDialog("Reset writing progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) {
                    ProgressStore.shared.reset()
                    JourneyStore.shared.reset()
                    PlanStore.shared.reset()
                }
            } message: {
                Text("Scores, streaks, course progress and your practice plan will be cleared.")
            }
        }
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
    }
}

private struct PracticeReminderRow: View {
    @State private var enabled = false
    @State private var busy = false
    @State private var message: String?
    private let center = UNUserNotificationCenter.current()
    private let reminderID = "penwise.practice"

    var body: some View {
        Toggle("Daily reminder at 6 PM", isOn: Binding(get: { enabled }, set: { value in
            busy = true
            Task { await changeReminder(to: value); busy = false }
        }))
        .disabled(busy)
        .task {
            let requests = await center.pendingNotificationRequests()
            let settings = await center.notificationSettings()
            enabled = settings.authorizationStatus != .denied && requests.contains { $0.identifier == reminderID }
        }
        if let message { Text(message).font(.footnote) }
    }

    @MainActor private func changeReminder(to value: Bool) async {
        message = nil
        if !value {
            center.removePendingNotificationRequests(withIdentifiers: [reminderID])
            enabled = false
            return
        }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                message = "To receive reminders, allow Penwise notifications in iPad Settings."
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Time for your workbook"
            content.body = "Pick up where you left off in Penwise."
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 18, minute: 0), repeats: true)
            try await center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
            enabled = true
        } catch { message = "The reminder could not be scheduled. Try again." }
    }
}
