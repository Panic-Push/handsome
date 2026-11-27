import SwiftUI

/// A clearly labelled space for an ad: a live AdMob banner when ads are
/// allowed, a placeholder of the same size when "Show ad placeholders" is on
/// in Settings, and nothing for Premium.
struct AdSlot: View {
    /// Whether ad spaces (and the entry screen that holds one) should appear.
    @MainActor static var shouldAppear: Bool {
        AdsService.shared.showsAds || previewEnabled
    }

    @MainActor private static var previewEnabled: Bool {
        #if DEBUG
        return AdsService.shared.eligible && AppSettings.shared.showAdPlaceholders
        #else
        return false
        #endif
    }

    @ObservedObject private var ads = AdsService.shared
    @ObservedObject private var store = StoreService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var loadFailed = false

    enum Placement {
        /// Shallow banner under the Home mode cards.
        case home
        /// Larger box on the screen between Home and a mode.
        case modeEntry

        var size: CGSize {
            switch self {
            case .home: return CGSize(width: 728, height: 90)
            case .modeEntry: return CGSize(width: 336, height: 280)
            }
        }
    }

    let placement: Placement

    var body: some View {
        if !store.isPremium && ((ads.showsAds && !loadFailed) || Self.previewEnabled) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ADVERTISEMENT")
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                if ads.showsAds && !loadFailed {
                    GeometryReader { geo in
                        AdBannerView(placement: placement == .home ? .homeBanner : .entry,
                                     width: min(geo.size.width, placement.size.width)) { loaded in
                            loadFailed = !loaded
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: placement.size.width)
                    .frame(height: placement.size.height)
                } else {
                    #if DEBUG
                    placeholder
                    #endif
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Advertisement")
        }
    }

    private var placeholder: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.07))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                Text("Ad preview")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: placement.size.width)
            .frame(height: placement.size.height)
    }
}
