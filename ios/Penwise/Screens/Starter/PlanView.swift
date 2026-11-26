import SwiftUI

/// The daily exercises are available alongside the handwriting check and its result.
struct PracticeSuggestions: View {
    @Binding var path: [Route]
    @ObservedObject private var plans = PlanStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = StoreService.shared

    var body: some View {
        if let today = plans.today {
            DisclosureGroup("Suggested practice · \(today.minutes) minutes") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(today.items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            if FeatureGate.canOpen(planItemAt: index) {
                                if item.kind != .words { plans.markDone(item) }
                                path.append(plans.route(for: item, style: settings.style))
                            } else {
                                path.append(.paywall)
                            }
                        } label: {
                            Label(item.title, systemImage: !store.isPremium && !FeatureGate.canOpen(planItemAt: index)
                                  ? "lock.fill" : plans.isDone(item) ? "checkmark.circle.fill" : "pencil")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                    if plans.report != nil { Button("Latest report") { path.append(.report) } }
                    Picker("Daily goal", selection: $plans.minutesPerDay) {
                        ForEach(PlanStore.minuteChoices, id: \.self) { Text("\($0) min").tag($0) }
                    }
                }
            }
            .padding().paperCard()
        }
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
