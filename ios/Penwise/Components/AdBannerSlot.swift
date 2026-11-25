import SwiftUI

/// Where the home-screen banner ad will go. Real ads (Google AdMob) and the
/// "Remove ads" purchase are added in Phase 2; until then this is a placeholder
/// of the same size, so the layout is final.
struct AdBannerSlot: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("AD")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            Text("Banner ad space")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Remove ads with Premium")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
