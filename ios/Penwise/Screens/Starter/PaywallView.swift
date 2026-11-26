import StoreKit
import SwiftUI

/// STARTER SCREEN (to be redesigned): Penwise Premium.
/// App Store review needs: price and period on each option, Restore,
/// and links to the privacy policy and terms of use.
struct PaywallView: View {
    @ObservedObject private var store = StoreService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Label("Every course: Normal, Classic and Traditional", systemImage: "book.closed")
                Label("Unlimited tests, words and sentences", systemImage: "infinity")
                Label("Your full daily plan", systemImage: "calendar")
                Label("No ads", systemImage: "nosign")
            } header: {
                Text("Penwise Premium")
            }
            Section {
                if store.isPremium {
                    Label("Premium is active. Thank you!", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                }
                if store.products.isEmpty {
                    Text(store.lastError ?? "Loading…").foregroundStyle(.secondary)
                }
                ForEach(store.products, id: \.id) { product in
                    Button {
                        Task {
                            switch await store.purchase(product) {
                            case .purchased: dismiss()
                            case .pending: message = "Waiting for approval."
                            case .cancelled: break
                            case .failed(let text): message = text
                            }
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(product.displayName).font(.headline)
                            Text(store.offerText(for: product)).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(store.isPremium)
                }
                Button("Restore purchases") { Task { await store.restore() } }
                if let message { Text(message).font(.footnote) }
            } footer: {
                Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in your Apple ID settings.")
            }
            Section {
                Link("Privacy policy", destination: AppLinks.privacyPolicy)
                Link("Terms of use", destination: AppLinks.terms)
            }
        }
        .navigationTitle("Premium")
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }
}
