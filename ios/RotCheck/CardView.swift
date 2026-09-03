import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// One card in the stack. The top card is draggable; the two behind it are
/// inert and scaled back to give the deck depth.
struct CardView: View {
    let card: PlayCard
    let depth: Int                       // 0 = top of the stack
    let onAnswer: (Bool) -> Void

    @State private var drag: CGSize = .zero

    private var isTop: Bool { depth == 0 }
    private var rotation: Double { Double(drag.width) * 0.055 }
    private var isLoud: Bool { card.isSponsor || card.isHighRot }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: card.isSponsor
                            ? [Color(hex: 0x241D00), Color(hex: 0x120E00)]
                            : card.isHighRot
                                ? [Theme.hardTop, Theme.hardBottom]
                                : [Theme.cardTop, Theme.cardBottom],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(borderColour, lineWidth: isLoud ? 2 : 1)
                )
                .shadow(color: glow, radius: isLoud ? 26 : 0)
                .shadow(color: .black.opacity(0.7), radius: 22, y: 18)

            content.padding(24)

            if isTop && !card.isSponsor { stamps }
        }
        .frame(maxWidth: 320)
        .frame(height: 270)
        .scaleEffect(1 - CGFloat(depth) * 0.06)
        .offset(y: CGFloat(depth) * 13)
        .opacity(depth == 0 ? 1 : depth == 1 ? 0.55 : 0.26)
        .offset(x: drag.width, y: drag.height * 0.28)
        .rotationEffect(.degrees(rotation))
        .gesture(dragGesture, including: isTop ? .all : .none)
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: depth)
    }

    // MARK: Pieces

    private var borderColour: Color {
        card.isSponsor ? Theme.sponsor : card.isHighRot ? Theme.ink : Theme.line
    }
    private var glow: Color {
        card.isSponsor ? Theme.sponsor.opacity(0.45) : card.isHighRot ? Theme.ink.opacity(0.4) : .clear
    }

    @ViewBuilder private var content: some View {
        if let sponsor = card.sponsor {
            SponsorCardContent(sponsor: sponsor)
        } else if let term = card.term {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text("REAL SLANG, OR AI SLOP?")
                        .font(Fonts.mono(10)).tracking(1.8)
                        .foregroundStyle(Theme.inkFaint)
                    Spacer(minLength: 0)
                    if card.isHighRot { HighRotBadge() }
                }
                Spacer(minLength: 8)
                Text(term.text.uppercased())
                    .font(Fonts.display(46))
                    .foregroundStyle(Theme.ink)
                    .shadow(color: card.isHighRot ? Theme.ink.opacity(0.45) : .clear, radius: 18)
                    .shadow(color: .black.opacity(0.5), radius: 0, x: 2, y: 3)
                    .minimumScaleFactor(0.45)
                    .lineLimit(3)
                Spacer(minLength: 8)
                Text("← fake  ·  real →")
                    .font(Fonts.ui(12.5))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// FAKE / REAL stamps that fade in as you drag.
    private var stamps: some View {
        ZStack {
            stamp("FAKE", Theme.fake, angle: -14)
                .opacity(drag.width < 0 ? min(1, Double(-drag.width) / 90) : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            stamp("REAL", Theme.real, angle: 14)
                .opacity(drag.width > 0 ? min(1, Double(drag.width) / 90) : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .padding(20)
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, _ colour: Color, angle: Double) -> some View {
        Text(text)
            .font(Fonts.display(20)).tracking(1.6)
            .foregroundStyle(colour)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(colour, lineWidth: 3))
            .rotationEffect(.degrees(angle))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > 85 {
                    onAnswer(value.translation.width > 0)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }
}

// MARK: - Sponsor card
//
// A real AdMob native ad when one is loaded, the house creative otherwise.
// Either way it's the loudest card in the deck, on purpose: that's what an
// advertiser is buying.

struct SponsorCardContent: View {
    let sponsor: Sponsor

    #if canImport(GoogleMobileAds)
    @State private var native: NativeAd?

    var body: some View {
        Group {
            if let native {
                NativeAdCard(ad: native)
            } else {
                house
            }
        }
        .onAppear {
            if native == nil { native = AdMobManager.shared?.takeNative() }
        }
    }
    #else
    var body: some View { house }
    #endif

    private var house: some View {
        VStack(alignment: .leading, spacing: 0) {
            HazardStripe().frame(height: 10).padding(.bottom, 14)
            Text("PAID PARTNERSHIP · SWIPE EITHER WAY")
                .font(Fonts.mono(10)).tracking(1.8)
                .foregroundStyle(Theme.sponsor)
            Spacer(minLength: 8)
            Text(sponsor.brand)
                .font(Fonts.display(34))
                .foregroundStyle(Theme.sponsor)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(sponsor.copy)
                .font(Fonts.ui(12.5))
                .foregroundStyle(Color(hex: 0xC9BE7A))
            Text(sponsor.cta)
                .font(Fonts.display(13)).tracking(0.8)
                .foregroundStyle(Theme.sponsorInk)
                .padding(.horizontal, 15).padding(.vertical, 8)
                .background(Capsule().fill(Theme.sponsor))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


/// Diagonal hazard stripes — the visual signature of the paid slot.
struct HazardStripe: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.groundDeep))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var bar = Path()
                bar.move(to: CGPoint(x: x, y: size.height))
                bar.addLine(to: CGPoint(x: x + size.height, y: 0))
                bar.addLine(to: CGPoint(x: x + size.height + step, y: 0))
                bar.addLine(to: CGPoint(x: x + step, y: size.height))
                bar.closeSubpath()
                context.fill(bar, with: .color(Theme.sponsor))
                x += step * 2
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// The High Rot marker. Neutral ink rather than a fourth hue, so it reads as
/// "stakes" without colliding with fake / real / sponsored.
struct HighRotBadge: View {
    @State private var pulse = false
    var body: some View {
        Text("HIGH ROT ×3")
            .font(Fonts.display(11)).tracking(0.8)
            .foregroundStyle(Theme.ground)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Theme.ink))
            .opacity(pulse ? 1 : 0.72)
            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}
