# ATLAS Suite

One iOS app combining four live BTC dashboards as tabs:

| Tab | Source repo | What it is |
|---|---|---|
| **LIVE** *(main)* | `alicetin1905-ux/BTCLiveBoard` | Full-screen split-flap price board with regime colour and alert tones |
| **ATLAS** | `alicetin1905-ux/ATLAS` | BTCUSDT.P signal scoring, MTF alignment, levels, and a paper trading desk |
| **CRUCIBLE** | `alicetin1905-ux/CRUCIBLE` | Liquidation tape across Bybit, Binance, OKX and Bitget, with cascade detection |
| **Golden Ratio** | `alicetin1905-ux/GoldenRatio` | Automatic Fibonacci retracement on BTCUSDT.P |

## Architecture: native shell, web dashboards

Each tab hosts the real dashboard in a `WKWebView` rather than a Swift rewrite.

That is a deliberate call. The four pages are ~5,000 lines of self-contained,
already-working JavaScript — a Chandelier Exit implementation, fractal swing
structure, a scoring engine, a liquidation-level model noted in the source as
"verified in node", and four exchange socket adapters. Porting that to Swift
would mean reimplementing tested numerical code with no way to prove the port
agrees with the original, and every future edit would have to be made twice.
Wrapping it keeps one copy of the logic and gets the app working now.

The native layer earns its place by doing things the page cannot do alone:

- **Persistent sessions.** Each tab's web view is created once and kept alive.
  CRUCIBLE holds open sockets to four exchanges; rebuilding the view on every
  tab switch would drop those feeds and empty the tape.
- **Working notifications.** WKWebView does not implement the Web Notifications
  API, so CRUCIBLE's cascade alerts would silently never fire. `NotificationBridge`
  shims `window.Notification` and delivers real iOS notifications, including
  while the app is in the foreground. **This is the main thing the app gives you
  over the page in a Safari tab.**
- **Offline fallback.** All three pages are bundled in the app. If the live copy
  can't load, the tab falls back to the bundled one automatically.
- **Stale-feed protection.** iOS suspends socket traffic for backgrounded web
  views. Returning after more than 30s reloads the tab rather than leaving stale
  prices looking live.
- **Keep screen awake on the live board.** The board is meant to be left
  running and glanced at, so the idle timer is held while it is the visible tab
  — and only there, since holding it on the read-and-put-away tabs would just
  burn battery. Toggle it from that tab's ⋯ menu.
- **Audible alert tones.** The board's WebAudio tones play through the ringer
  switch (`AVAudioSession` `.playback` with `.mixWithOthers`, so your music keeps
  going). Its sound toggle still starts off — nothing makes noise unasked.

### Live vs bundled

Tabs load from GitHub Pages by default, so a push to any of the four repos
reaches the app with no rebuild — and the page runs on the same origin it was
built and tested against, which avoids CORS surprises against the exchange APIs.

The bundled copies (`Resources/*.html`) are snapshots for offline use. Switch
between them per tab from the ⋯ menu.

One consequence worth knowing: live and bundled copies are different origins, so
they have **separate `localStorage`**. ATLAS's paper desk (`atlas-desk-v1`) and
CRUCIBLE's cascade log saved in live mode are not visible in bundled mode. The
three live tabs do share one origin, but their keys are namespaced, so they do
not collide.

## Requirements

- Xcode 16+ (the project uses file-system-synchronized groups, `objectVersion = 77`)
- iOS 17.0+

## Build

```
open AtlasSuite.xcodeproj
```

Set your team and bundle identifier under Signing & Capabilities. The simulator
runs as-is.

**This has not been compiled.** It was written in a Linux container with no
Swift toolchain or Xcode available, so expect to fix build errors on first open.

Two things to check on first build:
1. Target → Build Phases → Copy Bundle Resources should list `btcliveboard.html`,
   `atlas.html`, `crucible.html`, `goldenratio.html`. Xcode 16 assigns them
   automatically from the synchronized group, but confirm it — an empty bundled
   fallback is the failure you'd only notice offline.
2. Allow notifications when CRUCIBLE first asks, then confirm an alert arrives.

## Layout

```
AtlasSuite/
  AtlasSuiteApp.swift            entry point, tab bar appearance, scene phase
  Core/
    Module.swift                 the four tabs: titles, tints, URLs (order = tab order)
    AppState.swift               session ownership, keep-awake
    RootTabView.swift            tab shell
  Theme/Theme.swift              chrome colour matched to the pages' background
  Web/
    WebSession.swift             one long-lived WKWebView per tab, load & fallback
    DashboardTab.swift           native chrome: title, menu, error state
    DashboardWebView.swift       UIViewRepresentable
    BundledSchemeHandler.swift   serves bundled copies under bundled://
    NotificationBridge.swift     window.Notification → iOS notifications
    NetworkMonitor.swift         reachability, picks the initial source
  Resources/                     snapshots of the four dashboards
```

## Updating the bundled snapshots

```sh
curl -sL https://alicetin1905-ux.github.io/BTCLiveBoard/  -o AtlasSuite/Resources/btcliveboard.html
curl -sL https://alicetin1905-ux.github.io/ATLAS/       -o AtlasSuite/Resources/atlas.html
curl -sL https://alicetin1905-ux.github.io/CRUCIBLE/    -o AtlasSuite/Resources/crucible.html
curl -sL https://alicetin1905-ux.github.io/GoldenRatio/ -o AtlasSuite/Resources/goldenratio.html
```

## Note on distribution

This is built for personal/ad-hoc use. If you plan to submit it to the App Store,
be aware that App Review applies guideline 4.2 (minimum functionality) to apps
that are largely a wrapper around a website. The native notification bridge,
offline bundling and multi-tab shell are the arguments against that reading, but
it is a real risk worth knowing before you spend time on submission.

No API keys, credentials, or order placement exist anywhere in these dashboards —
ATLAS's desk is a local paper-trading simulator persisted in `localStorage`.

## Known compromises on the live board

- **No full-bleed mode.** The board is "full screen live price", but it keeps the
  standard 44pt nav bar like the other tabs. Its own top bar already fills both
  corners, so a floating control would overlap it, and there is no way to verify
  that layout without running the app. If you want the chrome gone, say so and
  I'll hide the nav bar — the tradeoff is finding somewhere for reload, source
  switching, and keep-awake to live.
- **Fullscreen and keyboard input removed.** The `F`-key fullscreen toggle and
  the `S` / `1`–`5` shortcuts are gone from the page, along with the footer hint
  that advertised them and the now-dead `kbd` styling. Everything they did is
  still reachable by tap: the symbol tiles were already real `<button>` elements
  and the sound control was already a click target, so nothing became
  unreachable. See "Patched live board" below.
- **Google Fonts offline.** The board is the one page that loads webfonts
  (JetBrains Mono, Inter). In bundled mode they won't fetch, and it falls back to
  SF Mono and system-ui — close enough that it still reads correctly.

## Patched live board

`AtlasSuite/Resources/btcliveboard.html` is **not** a verbatim snapshot — it has
the fullscreen option and keyboard handling removed. The change is five edits:

| Site | Change |
|---|---|
| footer hint | `Click a tile or press 1–5 … F fullscreen` → `Tap a tile to promote` |
| `keydown` listener | deleted entirely (fullscreen + `S` + `1`–`5`) |
| `tile.title` | dropped the `(1)`…`(5)` key number |
| `buildTiles` | unused `idx` parameter removed |
| CSS | dead `kbd{…}` rule removed |

The patched JavaScript passes `node --check`.

**This only applies in bundled mode until you push it.** The LIVE tab loads
`alicetin1905-ux.github.io/BTCLiveBoard/` by default, so the app keeps serving
the unpatched page until the same file lands in that repo. To make it real
everywhere, copy `AtlasSuite/Resources/btcliveboard.html` over the repo's
`index.html` and push. Until then you can switch that tab to "Bundled copy" from
its ⋯ menu to see the patched version.

On iPhone the visible difference is just the footer hint — there is no hardware
keyboard to press and `requestFullscreen` was already inert on iOS — but the
page is now honest about what it offers, and the code is gone rather than dead.

## Does a push to a repo show up in the app?

Yes — in **Live** mode (the default), with no rebuild and no App Store release.
Worth knowing exactly when:

**It refreshes on:** app launch · the first time you open that tab in a session ·
⋯ → Reload · returning to the app after more than 30s in the background.

**It does not** hot-swap a tab you are already staring at. The page is loaded
once and then left alone — that is deliberate, since re-loading would drop
CRUCIBLE's sockets and reset the board.

**Timing:** GitHub Pages takes roughly 10s–2min to rebuild after a push. If a
reload still shows the old page, Pages has not finished publishing yet — give it
a moment and reload again.

**Caching is handled.** Pages serves these with `cache-control: max-age=600`, so
the default policy would show a stale page for up to ten minutes after a push.
Live loads use `.reloadIgnoringLocalCacheData` and ⋯ → Reload calls
`reloadFromOrigin()`, both of which go to the origin.

> Avoid `.reloadRevalidatingCacheData` here — Apple documents it as unimplemented
> and it quietly falls back to the default protocol policy, honouring that
> ten-minute cache. That was a real bug in an earlier revision of this file.

**Bundled copies never update this way.** They are compiled into the app binary.
Refresh them with the `curl` commands above and rebuild in Xcode.

## Running it on your own iPhone

You need a **Mac with Xcode 16+**. There is no supported way to build a native
iOS app without macOS. A free Apple ID is enough — a paid developer account is
not required to run it on your own device.

1. Unpack the project and `open AtlasSuite.xcodeproj`.
2. Xcode → Settings → Accounts → **+** → add your Apple ID (free is fine).
3. Select the **AtlasSuite** target → **Signing & Capabilities**:
   - tick **Automatically manage signing**
   - set **Team** to your Apple ID
   - change **Bundle Identifier** from `com.example.AtlasSuite` to something
     unique to you, e.g. `com.alicetin.atlassuite` — the placeholder will be
     rejected as already taken.
4. Plug the iPhone in over USB and tap **Trust** on the phone.
5. Pick your iPhone from the run-destination menu at the top, then **⌘R**.
6. First launch fails with "Untrusted Developer" — on the phone go to
   **Settings → General → VPN & Device Management**, tap your Apple ID, and
   **Trust**. Launch again.
7. Allow notifications when asked, or CRUCIBLE's cascade alerts stay silent.

After the first install you can launch it from the home screen without the cable.

### Free account limits

- **The build expires after 7 days.** Re-run from Xcode to reset it. A paid
  account ($99/year) extends this to a year and unlocks TestFlight, which lets
  you install over the air with no cable.
- Three sideloaded apps on the device at once.
- Ten new app IDs per week.

### Expect build errors on the first open

None of this has been compiled — there is no Swift toolchain in the environment
it was written in. Paste any errors back and they can be fixed; the likely spots
are SwiftUI API shapes and Swift concurrency annotations, not the app's logic.
