# Rot Check

A 30-second swipe gauntlet. A slang term flies at you — swipe **right if it's real**, **left if it's AI slop**. A meter drains constantly; correct answers buy time, streaks multiply score, and every 5–8 cards a **sponsored card** enters the deck.

Roughly 1 in 5 cards is a **High Rot** card: triple points if you call it right, a 1.5× meter hit if you don't. The odds are weighted toward genuinely tricky terms but stay a dice roll, so the spike is never predictable.

The commercial idea in one line: **the core UI is the ad unit.** A swipe deck is a format media buyers already understand, so the highest-value inventory needs no extra screen, no extra art, and no interruption.

---

## Why this scales

| Constraint | How the design answers it |
|---|---|
| Content cost | The deck is a JSON array. 100 new cards is a data change, not an art pipeline. |
| Update cost | Set `CONTENT_URL` in `index.html` and the deck refreshes from a CDN — no store review. |
| Session length | ~25s per run drives high runs-per-session, so ad impressions per user are high. |
| Install friction | Ships as a PWA. A link opens the game; no store gate on the growth loop. |
| Ad quality | The sponsor card is native, full-screen, 100% viewable, and guarantees a swipe interaction. |
| Localisation | Each locale is another JSON deck. The code doesn't change. |

---

## Files

```
index.html               web/PWA build — no build step, no dependencies
manifest.webmanifest     PWA install metadata
sw.js                    offline shell cache
icon.svg + icon-*.png    icon set (regenerate: python tools/make-icons.py)
ios/                     native SwiftUI app — see ios/README.md
dist/rot-check.html      single-page build for sharing
tools/make-icons.py      icon generator
tools/build-artifact.py  produces dist/ from index.html
```

Three builds, one game design. The web build is the growth loop (a link, no
install). The native iOS app is the App Store product. Play can take either.

## Run it

```bash
python -m http.server 8080
```

Then open `http://localhost:8080`. A service worker needs `http://localhost` or HTTPS — opening the file directly with `file://` disables install and offline.

## Deploy it

Any static host. Free tiers are more than enough to start:

```bash
npx vercel deploy --prod
```

Netlify, Cloudflare Pages, and GitHub Pages all work identically — upload the folder. HTTPS is required for the PWA install prompt and for most ad networks.

---

## Android and iPhone

### Now: install as a PWA (zero review, zero fees)

Already wired. On Android/Chrome the install banner fires from `beforeinstallprompt`. On iOS Safari the game detects the platform and shows the "Share → Add to Home Screen" hint, since iOS has no programmatic install.

Once installed it runs full-screen with no browser chrome, works offline, and keeps scores locally.

Mobile hardening already in the build:
- `100dvh` and `env(safe-area-inset-*)` so notches and the iOS URL bar don't clip the UI
- `overscroll-behavior: none` — pull-to-refresh can't kill a run mid-swipe
- double-tap-zoom and long-press menus suppressed on cards
- Pointer Events, so one code path covers touch, mouse, and stylus
- 56px minimum touch targets
- `navigator.vibrate` haptics on hit, miss, and death
- **backgrounding pauses the timer** — switching apps can't drain your meter

### iOS: a real native app

**`ios/` contains a full SwiftUI port — not a WebView wrapper.** Apple's
Guideline 4.2 rejects apps that are essentially a website in a shell, and a
swipe game is exactly the shape reviewers challenge. Native also unlocks the
AdMob SDK, which pays better than web ads on identical traffic.

Setup, ad wiring, and the full App Store submission walkthrough are in
[ios/README.md](ios/README.md). It needs a Mac and $99/yr.

### Android: Capacitor is fine here

Play has no equivalent of Guideline 4.2, so wrapping `index.html` is a
legitimate shortcut that ships in a day.

```bash
npm init -y
npm i @capacitor/core @capacitor/cli @capacitor/android @capacitor/ios
npx cap init "Rot Check" com.yourstudio.rotcheck --web-dir=.
npx cap add android
npx cap add ios
npx cap sync
npx cap open android    # needs Android Studio
npx cap open ios        # needs Xcode on a Mac
```

Then add the ad plugin — `ADS.init()` already detects and uses it:

```bash
npm i @capacitor-community/admob
```

Google Play is a one-time $25. Note that new *personal* Play accounts must run
a closed test with 12 testers for 14 continuous days before production access —
plan around it. Full detail in [ios/README.md](ios/README.md), which covers both
stores.

---

## Getting ads in

`ADS` in `index.html` is one interface with three providers, tried in order. Swapping networks means editing that one block — nothing else in the game knows or cares.

### 1. AdMob — native builds (best rates)

The native iOS app already implements this end to end in `ios/RotCheck/AdManager.swift`.
For the web/Capacitor build:

Sign up at `admob.google.com`, create the app, create an **interstitial** and a **rewarded** unit, then paste the IDs into `_admobIds` in `index.html`:

```js
this._admobIds = {
  interstitial: "ca-app-pub-XXXXXXXX/YYYYYYYY",
  rewarded:     "ca-app-pub-XXXXXXXX/ZZZZZZZZ"
};
```

Detection, error handling, and the house-ad fallback on no-fill are already implemented.

### 2. H5 Games Ads — mobile web

For the PWA build, this is the web equivalent and it's the reason the `adBreak` path exists. Apply through AdSense, then add before `</head>`:

```html
<script async data-ad-frequency-hint="30s"
  src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXX"
  crossorigin="anonymous"></script>
```

`ADS.init()` sees `adConfig` and switches over automatically. Requires an approved AdSense account and a live HTTPS domain.

### 3. House ads — the default

Ships enabled so the game never shows an empty slot, and so you can demo the full ad experience to a buyer before any network is live.

### Worth adding once you have scale

- **Mediation** (AppLovin MAX or AdMob mediation) makes networks bid against each other. Typically lifts eCPM 20–50% for a day of setup — do this before optimising anything else.
- **AppLovin / Unity Ads / ironSource** as extra demand sources in that mediation stack. Unity and ironSource are strong on rewarded video specifically.

---

## Selling directly to advertisers

This is where the margin is — no network revenue share. Three products, roughly in the order you can sell them:

**1. The in-deck sponsor card.** Your premium unit. Pitch it honestly: native to the core loop, full-screen, 100% viewability, and a *guaranteed swipe interaction* rather than a passive impression. Sold on CPM, priced well above interstitial because of the interaction guarantee.

**2. Branded deck takeover.** A themed content pack — "Rot Check: <Brand> Edition" — where the brand's own slang and campaign lines are woven into the real deck. This is a flat-fee sponsorship, not CPM, and it is the single highest-ticket thing you can sell. It works because the deck is just JSON: a takeover is a content drop, not an engineering project.

**3. Rewarded revive sponsorship.** "Continue, brought to you by X." The player *chose* to watch, so attention is genuinely high, and rewarded is already the best-paying format in mobile.

**Sequencing matters.** Nobody buys direct below roughly 50k DAU — you don't have the reach to justify a buyer's time. Run networks from day one for baseline revenue, and start direct conversations only once the audience is real. The metrics drawer in the game is built for exactly that meeting: it shows live impressions-per-session and projects them to scale.

---

## Revenue model

These are **illustrative assumptions, not projections** — real numbers depend enormously on geography, since US/UK/CA traffic can earn 4–10× what most other markets do.

Per session, this build's current pacing delivers roughly 4 sponsor cards, 3 interstitials, and 0.4 rewarded views.

At 100,000 DAU and one session per user per day (3M sessions/month):

| Unit | Monthly impressions | eCPM (US-heavy) | Revenue |
|---|---:|---:|---:|
| Sponsor cards | 12.0M | $4 | $48,000 |
| Interstitials | 9.0M | $9 | $81,000 |
| Rewarded | 1.2M | $22 | $26,400 |
| **Total** | | | **~$155,000/mo** |

With a globally-mixed audience, expect the blended eCPM to land nearer a quarter of that — call it **$35–60k/month** at the same 100k DAU. Treat the US-heavy column as the ceiling, not the plan.

**The lever that matters most is retention, not ad density.** Doubling ads per session annoys players into churning; doubling D7 retention doubles revenue permanently. Tune `AD_EVERY` and the `M.runs >= 2` interstitial gate carefully, and watch session length when you do.

---

## Compliance — read before switching ads on

This genuinely affects revenue, so treat it as part of the monetization plan rather than paperwork.

- **Audience age is the big one.** Brainrot humour skews young. If your audience is meaningfully under 13, COPPA and Google Play's Families policy apply: no personalised ads, no ad ID collection, and eCPM drops hard. Decide deliberately whether you are targeting 13+ and set the store age rating and AdMob's tag-for-child-directed-treatment flag to match — mismatches get apps pulled.
- **iOS App Tracking Transparency.** Native iOS builds need the ATT prompt before personalised ads. Expect a large share of users to decline; that is normal and already priced into typical eCPMs.
- **GDPR/CCPA consent.** Serving EU or California traffic requires a certified consent management platform. Google's UMP SDK is free and integrates with AdMob.
- **Ad labelling.** Sponsored cards must be visibly labelled. The build already renders "Paid partnership" plus a hazard-striped frame; keep it.
- **Content.** Keep the deck free of real people's names and trademarks you don't have rights to. The bundled fake terms are invented; the sponsor brands are fictional placeholders.

---

## Growth loop

The share card is already wired to the Web Share API with a clipboard fallback. The mechanic that actually spreads is **disagreement** — people share a term they were *sure* was fake. Lean into that: surface "87% of players got this wrong" on the game-over screen once you have a backend counting answers.

Cheapest next wins, in order:

1. **Daily deck** — one fixed deck per day so scores are comparable, which makes sharing meaningful and gives people a reason to return.
2. **Answer stats backend** — a single counting endpoint unlocks the disagreement hook above.
3. **TikTok/Shorts clips** — screen-record hard cards. This game's own subject matter is its distribution channel.

---

## Roadmap

Content and retention first; both raise ad revenue more than ad tuning does.

- [ ] Expand the deck to 300+ terms, split into difficulty tiers
- [ ] Daily deck + streak calendar
- [ ] Server-side answer stats for the "you and 87% of players" hook
- [ ] Leaderboard (needs accounts or device IDs)
- [ ] Localised decks — each is a new market on the same code
- [ ] Mediation, then direct sales at 50k DAU
