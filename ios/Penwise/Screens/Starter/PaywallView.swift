import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject private var store = StoreService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?
    @State private var purchasing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.isPremium {
                    WorkbookFox(pose: .celebrate).frame(height: 132)
                    Text("Your Premium workbook is ready").font(.workbook(.largeTitle))
                    Text("Your full daily plan is open. Enjoy an ad-free workbook on this iPad.")
                    if let end = store.trialEnds {
                        LabeledContent("Your free week ends", value: end.formatted(date: .long, time: .omitted))
                    }
                    Link("Manage subscriptions", destination: AppLinks.subscriptions)
                    Button("Continue writing") { dismiss() }.buttonStyle(LessonActionStyle())
                } else {
                    Label("Penwise Premium", systemImage: "book.closed.fill").font(.headline)
                    Text("Make time for your handwriting").font(.workbook(.largeTitle))
                    Label("Open every activity in your daily plan", systemImage: "checklist")
                    Label("Practise without ads", systemImage: "pencil.and.scribble")
                    if store.isLoading && store.products.isEmpty {
                        ProgressView("Loading prices")
                    } else if store.products.isEmpty {
                        Text(store.lastError ?? "Purchase options are unavailable.")
                        Button("Try again") { Task { await store.loadProducts() } }
                    }
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            purchasing = true
                            Task {
                                defer { purchasing = false }
                                switch await store.purchase(product) {
                                case .purchased: message = nil
                                case .pending: message = "Waiting for purchase approval."
                                case .cancelled: message = nil
                                case .failed(let text): message = text
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(product.displayName).font(.workbook(.title3))
                                    Text(store.offerText(for: product)).font(.body)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }.padding(18).paperCard()
                        }.buttonStyle(.plain).disabled(purchasing)
                    }
                    Text("Manage or cancel subscriptions in your Apple Account at least 24 hours before the end of the current period.").font(.footnote)
                }
                if let message { Text(message) }
                Button("Restore purchases") {
                    Task {
                        await store.restore()
                        message = store.lastError ?? (store.isPremium ? "Purchases restored." : "No active purchases found.")
                    }
                }.disabled(purchasing)
                NavigationLink("Privacy policy") { PrivacyPolicyView() }
                Link("Terms of use", destination: AppLinks.terms)
            }
            .padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
        .background(Color.paper)
        .navigationTitle("Premium")
        .task { await store.loadProducts() }
    }
}
