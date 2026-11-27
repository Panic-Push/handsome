import GoogleMobileAds
import SwiftUI
import UIKit

/// A live AdMob banner. Use it through `AdSlot`, which reserves the space and
/// falls back to nothing (or a placeholder) when ads are off.
struct AdBannerView: UIViewRepresentable {
    let placement: AdsService.Placement
    /// Width available for an adaptive home banner.
    var width: CGFloat = 728
    var onLoad: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(onLoad: onLoad) }

    func makeUIView(context: Context) -> BannerView {
        let size: AdSize = placement == .entry
            ? AdSizeMediumRectangle
            : largeAnchoredAdaptiveBanner(width: width)
        let banner = BannerView(adSize: size)
        banner.adUnitID = placement.unitID
        banner.rootViewController = AdsService.rootViewController()
        banner.delegate = context.coordinator
        if AdsService.shared.showsAds, !placement.unitID.isEmpty { banner.load(Request()) }
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        let onLoad: ((Bool) -> Void)?
        init(onLoad: ((Bool) -> Void)?) { self.onLoad = onLoad }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) { onLoad?(true) }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) { onLoad?(false) }
    }
}
