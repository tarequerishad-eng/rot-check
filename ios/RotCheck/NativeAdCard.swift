#if canImport(GoogleMobileAds)
import SwiftUI
import UIKit
import GoogleMobileAds

/// The in-deck sponsor card, filled by a real AdMob native ad and styled to
/// match the hazard-yellow house version. UIKit underneath because the SDK
/// needs a `NativeAdView` with registered asset views to count impressions
/// and route clicks.
///
/// Policy notes baked in: visible "AD" attribution; media view shown; the CTA
/// has user interaction disabled so the SDK handles the tap; the top-right
/// corner is left clear for the AdChoices icon the SDK inserts.
struct NativeAdCard: UIViewRepresentable {
    let ad: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let view = NativeAdView()
        view.backgroundColor = .clear

        let yellow    = UIColor(Theme.sponsor)
        let yellowInk = UIColor(Theme.sponsorInk)
        let body      = UIColor(Color(hex: 0xC9BE7A))
        let faint     = UIColor(Theme.inkFaint)

        // "AD" attribution — required, and it doubles as the eyebrow.
        let badge = UILabel()
        badge.text = "  AD  "
        badge.font = Fonts.uiFont(.mono, 10)
        badge.textColor = yellowInk
        badge.backgroundColor = yellow
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true

        let advertiser = UILabel()
        advertiser.font = Fonts.uiFont(.mono, 10)
        advertiser.textColor = faint

        let headline = UILabel()
        headline.font = Fonts.uiFont(.display, 20)
        headline.textColor = yellow
        headline.numberOfLines = 2
        headline.adjustsFontSizeToFitWidth = true
        headline.minimumScaleFactor = 0.7

        let media = MediaView()
        media.contentMode = .scaleAspectFill
        media.clipsToBounds = true
        media.layer.cornerRadius = 10
        media.backgroundColor = UIColor(Theme.groundDeep)

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFill
        icon.clipsToBounds = true
        icon.layer.cornerRadius = 8

        let bodyLabel = UILabel()
        bodyLabel.font = Fonts.uiFont(.ui, 12)
        bodyLabel.textColor = body
        bodyLabel.numberOfLines = 2

        let cta = UIButton(type: .system)
        var cfg = UIButton.Configuration.filled()
        cfg.baseBackgroundColor = yellow
        cfg.baseForegroundColor = yellowInk
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        cfg.cornerStyle = .medium
        cta.configuration = cfg
        cta.isUserInteractionEnabled = false     // the SDK owns the tap
        cta.setContentCompressionResistancePriority(.required, for: .horizontal)

        for v in [badge, advertiser, headline, media, icon, bodyLabel, cta] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        // Register assets so impressions and clicks are tracked.
        view.headlineView = headline
        view.mediaView = media
        view.bodyView = bodyLabel
        view.iconView = icon
        view.callToActionView = cta
        view.advertiserView = advertiser

        let g = view
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: g.topAnchor),
            badge.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            badge.heightAnchor.constraint(equalToConstant: 18),

            advertiser.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            advertiser.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8),
            // leave ~40pt top-right for AdChoices
            advertiser.trailingAnchor.constraint(lessThanOrEqualTo: g.trailingAnchor, constant: -44),

            headline.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 8),
            headline.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            headline.trailingAnchor.constraint(equalTo: g.trailingAnchor),

            media.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 8),
            media.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            media.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            media.heightAnchor.constraint(equalToConstant: 84),

            icon.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            icon.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),

            bodyLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            bodyLabel.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            bodyLabel.trailingAnchor.constraint(lessThanOrEqualTo: cta.leadingAnchor, constant: -10),

            cta.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            cta.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            media.bottomAnchor.constraint(lessThanOrEqualTo: icon.topAnchor, constant: -8)
        ])

        return view
    }

    func updateUIView(_ view: NativeAdView, context: Context) {
        (view.headlineView as? UILabel)?.text = ad.headline
        view.mediaView?.mediaContent = ad.mediaContent
        (view.bodyView as? UILabel)?.text = ad.body
        (view.iconView as? UIImageView)?.image = ad.icon?.image
        view.iconView?.isHidden = ad.icon == nil
        (view.advertiserView as? UILabel)?.text = ad.advertiser
        view.advertiserView?.isHidden = ad.advertiser == nil

        if let button = view.callToActionView as? UIButton {
            var title = AttributedString((ad.callToAction ?? "LEARN MORE").uppercased())
            title.uiKit.font = Fonts.uiFont(.display, 13)
            button.configuration?.attributedTitle = title
            button.isHidden = ad.callToAction == nil
        }

        // Setting this last registers the impression.
        view.nativeAd = ad
    }
}
#endif
