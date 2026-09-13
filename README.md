# iOSAPP

Two ways to run the four BTC dashboards as one app on iPhone.

| | What it is | Needs a Mac |
|---|---|---|
| **`/` (this site)** | Installable web app — four tabs, added to the Home Screen | no |
| **`ios/`** | Native SwiftUI app wrapping the same four boards | yes |

The web app is the one to try first. It does nearly everything the native app
does, installs in seconds, and updates the moment you push.

## The web app

Live at **https://alicetin1905-ux.github.io/iOSAPP/**

| Tab | Loads |
|---|---|
| **Live** | `/BTCLiveBoard/` |
| **ATLAS** | `/ATLAS/` |
| **Crucible** | `/CRUCIBLE/` |
| **Fibo** | `/GoldenRatio/` |

### Install it

1. Open the link above **in Safari on the iPhone**.
2. **Share → Add to Home Screen.**
3. Launch it from the icon.

Step 3 is not optional. iOS only grants notifications, wake lock and full-screen
display to a web app launched from the Home Screen — in a Safari tab it is just a
web page, and a banner says so until you install it.

### How it works

Each board loads in its own iframe the first time you open its tab, then stays
**alive** in the background. Switching tabs only shows and hides them, so
CRUCIBLE's four exchange sockets and the live board's tape keep running instead
of restarting on every switch.

Tapping the tab you are already on **reloads** that board — handy right after
pushing a change to its repo.

The Live tab holds a **Screen Wake Lock** while visible so the board does not
dim, releasing it on other tabs and whenever the app is hidden.

The tabs load the four dashboards by absolute path on this same origin, so a push
to any of those four repos shows up here with no change to this one.

### Note on paths

This site is served from `/iOSAPP/`, not the domain root, so the manifest uses
`start_url` and `scope` of `./`. If you ever move it to a repo named
`alicetin1905-ux.github.io`, it serves from `/` and those can become `/`.

Scope does not affect the tabs either way: the hub reaches the boards through
iframes, never top-level navigation.

## The native app

See `ios/README.md`. It is a SwiftUI tab shell hosting the same four pages in
long-lived `WKWebView`s, with a bridge that turns CRUCIBLE's `Notification` calls
into real iOS notifications.

**It has never been compiled** — it was written in an environment with no Swift
toolchain — so expect to fix build errors on first open in Xcode.

## What neither one solves

**Alerts only fire while the app is open.** iOS suspends the sockets when the app
is backgrounded, so a cascade firing while the phone is in your pocket notifies
nobody. Fixing that needs something server-side holding the exchange
connections, running the cascade model, and sending Web Push.
