import SwiftUI

/// STARTER SCREEN (to be redesigned): today's personal plan.
struct PlanView: View {
    @Binding var path: [Route]
    @ObservedObject private var plans = PlanStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = StoreService.shared

    var body: some View {
        List {
            if plans.needsAssessment {
                Section {
                    Text("Take a 3-minute handwriting check to get a plan made for you.")
                    Button("Start the handwriting check") { path.append(.assessment) }
                }
            } else if let today = plans.today, let report = plans.report {
                Section("Today · \(today.minutes) minutes") {
                    ForEach(Array(today.items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            open(item, at: index)
                        } label: {
                            HStack {
                                Image(systemName: plans.isDone(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(plans.isDone(item) ? Color.green : Color.secondary)
                                VStack(alignment: .leading) {
                                    Text(item.title).font(.headline)
                                    Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !FeatureGate.canOpen(planItemAt: index) { Image(systemName: "lock.fill") }
                                Text("\(item.minutes) min").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Picker("Minutes a day", selection: $plans.minutesPerDay) {
                        ForEach(PlanStore.minuteChoices, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Button("See my report") { path.append(.report) }
                    Button(plans.reassessmentDue ? "Time for a new check" : "Retake the handwriting check") {
                        path.append(.assessment)
                    }
                } footer: {
                    Text("Focus: \(report.focusTitles.joined(separator: ", "))")
                }
            }
        }
        .navigationTitle("Your plan")
        .onAppear { plans.refresh() }
    }

    private func open(_ item: PlanItem, at index: Int) {
        guard FeatureGate.canOpen(planItemAt: index) else {
            path.append(.paywall)
            return
        }
        if item.kind != .words { plans.markDone(item) }
        path.append(plans.route(for: item, style: settings.style))
    }
}

/// STARTER SCREEN: the latest report.
struct ReportView: View {
    @ObservedObject private var plans = PlanStore.shared

    var body: some View {
        ScrollView {
            if let report = plans.report {
                ReportContent(report: report).padding(28)
            } else {
                Text("No report yet.").padding(28)
            }
        }
        .navigationTitle("Your report")
    }
}
