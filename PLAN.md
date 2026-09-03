# Rot Check — iOS build plan

*Approved 2026-09-01 with all defaults. Research date: 2026-09-01.*

**Status:** everything that doesn't need a Mac is done — Phases 2 and 3 are
written (see `ios/README.md` for the file map), the deck is at 606 terms, and
both web builds share the same `deck.json`. What's left is the Mac: create the
Xcode project, compile, fix first-build errors, run on the iPhone, tune the
feel, then Phase 0's accounts and Phase 4's store listing.

---

## 0. Verdict: expand it, don't remake it

The core loop — swipe judgement, draining meter, streak multiplier, High Rot risk/reward — is sound and already tested in the web build. The SwiftUI architecture (pure `GameModel`, thin views, ads behind one protocol) is the right shape. Remaking would throw away the only part that's verified.

What's actually wrong is narrower and more specific:

| Problem | Severity | Why |
|---|---|---|
| Ad SDK code targets Google Mobile Ads **v11**; Xcode 26 is mandatory since April 2026 and v12 renamed every class | Blocks compile | `MobileAds.shared`, `InterstitialAd.load(with:)`, `present(from:)` |
| No `PrivacyInfo.xcprivacy` | Blocks upload | Required since May 2024; the app touches `UserDefaults` (reason `CA92.1`) |
| No consent flow (UMP) | Loses EEA/UK/CH revenue | Without a certified CMP, Google serves only Limited Ads there |
| No `SKAdNetworkItems` | Loses attributed demand | Buyers won't bid without it |
| **58 terms** in the deck | Kills retention | A player sees repeats on run 3; content is the #1 churn driver in this genre |
| No reason to return tomorrow | Kills retention | No daily mode, no streak, no leaderboard |
| Sponsor card is house-ads only | Leaves money on the table | AdMob native ads can fill that exact slot with real demand from day one |
| No Remove Ads purchase | Leaves money on the table | Every competitor has it; it's the standard second revenue line |

So: fix the compile/compliance layer, then add the money layer, then the retention layer. Three additive phases on top of what exists.

---

## 1. What the research changed

**Competitors are beatable.** The three brainrot quizzes on the App Store are all *"name the character from the picture"* trivia, rated 4+/9+, ~870 ratings each, 28–250 MB, and **none has shipped an update since 2025**. They're anchored to the 2025 Italian brainrot characters, which the trend coverage says are fading while the absurdist genre itself continues. Rot Check's mechanic — *is this slang real?* — is trend-agnostic; each new wave is a content drop, not a rebuild. That's the differentiation and it's real.

**"Rot Check" is free** as an App Store name.

**Rate it 13+.** Apple replaced 12+/17+ with 13+/16+/18+ in 2025. 13+ keeps personalised ads and normal eCPMs, matches the actual audience, and needs a content audit to strip anything that would push to 16+ (remove `gooning`; review the rest).

**eCPMs are better than I assumed.** US iOS rewarded ≈ $19.6, interstitial ≈ $14 (2026 benchmarks). Global blend runs roughly a third of that. Rewarded is the format to maximise.

**AdMob is right for launch; MAX later.** Mediation only pays back above ~$5k/month. Start on AdMob alone, revisit at that threshold.

**Zero backend is achievable.** Daily mode seeds from the date. Leaderboards are Game Center. Content refresh is a JSON file on any static host. Reminders are local notifications. Nothing to run, nothing to pay for, nothing to break at 2am.

---

## 2. Where the money comes from

In order of expected contribution:

1. **Rewarded video** — revive (exists) + **Double Your Score** at game over (new). Highest eCPM format; two placements per run is the genre standard.
2. **Interstitial** — after game over, from run 2, with a **45-second minimum gap** so it doesn't fire on quick retries. Networks reward this pacing; players tolerate it.
3. **Native ad in the deck** — the sponsor card slot, filled by AdMob native demand instead of house creative. This is the differentiated unit and it earns from day one now rather than at 50k DAU.
4. **Remove Ads** — $2.99 non-consumable via StoreKit 2. Competitors charge $0.99; a higher price at lower conversion usually nets more, and it's still impulse territory. Kills interstitials and native cards; keeps rewarded (player-initiated, and they want it).

**Honest expectation.** Ads are a volume game. Roughly 10 impressions per DAU per day at ~$8 blended global eCPM:

| DAU | Monthly ad revenue |
|---:|---:|
| 200 | ~$500 |
| 2,000 | ~$5,000 |
| 10,000 | ~$24,000 |

Plus Remove Ads at ~1–2% of installs × $2.99. A US-heavy audience roughly doubles the ad line. Organic launches land in the hundreds of DAU; the retention layer below is what earns the right to the higher rows. Anyone promising more than this without a UA budget is guessing.

---

## 3. The build

### Phase 0 — Before 7 September (accounts, no code)

Lead-time items that run in the background:

- [ ] **Apple Developer Program** — $99/yr. Individual is fast; organisation needs a D-U-N-S number and takes weeks.
- [ ] **AdMob account** — free. Create the app entry; note the App ID. New accounts have a review period before full ad serving, so earlier is better.
- [ ] **Confirm the MacBook Air runs macOS 15.6 or later** — Xcode 26 requires it. If it can't, this plan needs a different Mac.
- [ ] **Bundle ID decision** — e.g. `com.yourname.rotcheck`. Needed for the project, AdMob, Game Center, and IAP.

### Phase 1 — Compile and run (days 1–2)

Milestone: **the game plays on your iPhone.**

- [ ] Xcode project, iOS 16 minimum deployment, portrait only
- [ ] Import the eight Swift files; fix first-build errors (expect a handful — the code has never seen a compiler)
- [ ] Bundle the four fonts
- [ ] AppIcon from `tools/make-icons.py`
- [ ] Run on device by cable; play ten rounds; **tune `drainBase` and the 85-pt swipe threshold by feel** — this is the one thing I couldn't test and it matters more than anything in Phase 2

### Phase 2 — Money and compliance (days 3–6)

- [ ] **Rewrite `AdManager.swift` for GMA v12** — SPM package, new names, `AdLoader` for native
- [ ] **UMP consent flow** — `ConsentInformation.shared.requestConsentInfoUpdate` → `ConsentForm.loadAndPresentIfRequired` → only then `MobileAds.shared.start`. Privacy-options entry point in settings when `privacyOptionsRequirementStatus == .required`
- [ ] **ATT prompt** after the first completed run, sequenced after UMP
- [ ] **`Info.plist`**: `GADApplicationIdentifier`, `NSUserTrackingUsageDescription`, `SKAdNetworkItems` (Google's `cstr6suwn9.skadnetwork` plus the current buyer list from AdMob docs)
- [ ] **`PrivacyInfo.xcprivacy`**: `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`; tracking = true; collected data types matching AdMob
- [ ] **Native ad card** — `UIViewRepresentable` wrapping `NativeAdView`; headline + body + CTA + icon + `MediaView`; AdChoices corner reserved; "Ad" attribution visible; CTA `isUserInteractionEnabled = false` so the SDK handles the tap. House card remains the no-fill fallback.
- [ ] **Double Your Score** rewarded placement on game over
- [ ] **Interstitial pacing** — run ≥ 2 and ≥ 45 s since the last one
- [ ] **Remove Ads** — StoreKit 2, `Product.products(for:)`, `Transaction.currentEntitlements`, restore button. Gates interstitials + native; rewarded stays.
- [ ] Verify with Google's test unit IDs (already in the code and confirmed correct); swap to real IDs at Phase 4

### Phase 3 — Retention and growth (days 7–11)

- [ ] **Deck to 300+ terms**, tiered (`tricky` flag), 13+ content audit. This is the largest single task and it's content, not code — I'll write it.
- [ ] **Daily Rot** — 20 fixed cards, deterministic from the date seed, one attempt per day, everyone gets the same deck. Separate mode on the title screen.
- [ ] **Emoji result grid** — `🟩🟥🟨` per card (`🟨` = High Rot nailed), spoiler-free, one tap to share. The Wordle mechanic; it took that game from 90 players to 3 million on zero marketing.
- [ ] **Streak calendar** for Daily Rot, local
- [ ] **Game Center** — two leaderboards (Endless all-time, Daily Rot today). `GKLeaderboard.submitScore`, `GKAccessPoint`. Configured in App Store Connect.
- [ ] **Local reminder** — "Today's Rot is ready" via `UNUserNotificationCenter`, opt-in, user-chosen time
- [ ] **Remote deck** — fetch `deck.json` from a static URL on launch, cache, fall back to bundled. Content updates without review.

### Phase 4 — Ship (days 12–16)

- [ ] Real AdMob unit IDs; `tagForChildDirectedTreatment = false`
- [ ] App Store Connect: app record, **13+** age questionnaire, Game Center leaderboards, IAP product
- [ ] Privacy policy page (static host; must disclose AdMob data collection) — required for submission
- [ ] App Privacy labels matching the SDKs actually shipped
- [ ] 6.9" screenshots (1320 × 2868) — up to 10; first three carry the pitch
- [ ] Listing: name **Rot Check**, subtitle *Real slang or AI slop?*, keywords: brainrot, slang, gen z, quiz, rizz, skibidi, sigma, aura, meme, trivia
- [ ] Archive → TestFlight → a few days on real phones → submit

**~3 weeks to submission** at a few hours a day.

---

## 4. Architecture changes (file level)

```
ios/RotCheck/
  GameModel.swift        + Daily mode, date seed, result grid, 2× score, interstitial pacing
  Deck.swift             → loads bundled 300+ deck; overlaid by remote fetch
  DeckLoader.swift       NEW — remote JSON fetch + cache
  AdManager.swift        REWRITE — GMA v12, native loader, consent-gated init
  ConsentManager.swift   NEW — UMP flow, ATT sequencing, privacy options
  NativeAdCard.swift     NEW — UIViewRepresentable NativeAdView styled as the sponsor card
  Store.swift            NEW — StoreKit 2 Remove Ads
  GameCenter.swift       NEW — auth, submit, access point
  Reminders.swift        NEW — local notification
  ShareCard.swift        NEW — emoji grid + ShareLink
  Views/…                Daily mode entry, settings (privacy options, restore, reminder), share sheet
  PrivacyInfo.xcprivacy  NEW
```

`GameModel` stays free of UIKit and network code so it remains testable. Nothing here needs a server.

---

## 5. Risks, honestly

1. **The Swift has never compiled.** Budget a day. The v12 rewrite removes the biggest known source of errors.
2. **macOS 15.6+ on the Air is non-negotiable** for Xcode 26. Check first.
3. **AdMob's app review** can throttle serving for days to weeks after the app goes live. Revenue in week one may lag the install curve.
4. **Content accuracy.** My real/fake labels are judgement calls; one wrong "real" is a one-star review. A review pass on the 300 before ship.
5. **Review rejection vectors**: privacy labels not matching SDKs; ATT string missing; test unit IDs left in; ads not labelled. All checklisted above.
6. **Trend timing.** The Italian brainrot characters are cooling. The mechanic doesn't depend on them — but the first content drop after launch should already be the *next* wave, not more of the last one.

---

## 6. Decisions needed before Phase 1

Defaults are stated; say nothing and these apply.

1. **Age rating: 13+** — removes a few crude terms, keeps full ad revenue.
2. **Remove Ads price: $2.99** — drop to $1.99 if conversion is under 1% after two weeks.
3. **Name: Rot Check** — confirmed available.
4. **Bundle ID** — I need this from you; there's no sensible default. `com.<yourname>.rotcheck` works.
5. **Daily Rot mode: yes** — it's the growth engine; without it there is no organic curve.

---

## 7. Explicitly not in this build

Android (later, via Capacitor — Play is lenient), localisation, any backend, Firebase, achievements, direct-sold sponsorships (needs ~50k DAU first), AppLovin MAX (needs ~$5k/month first). Each is a follow-on, not a gap.
