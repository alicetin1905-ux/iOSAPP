# Making each dashboard installable on its own (optional)

The hub already installs all four as one app. Do this only if you also want a
separate Home Screen icon for an individual board.

Add to the `<head>` of that repo's `index.html`:

```html
<link rel="manifest" href="manifest.webmanifest">
<meta name="theme-color" content="#070a0f">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="CRUCIBLE">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
```

Then add `manifest.webmanifest` beside it:

```json
{
  "name": "CRUCIBLE",
  "short_name": "CRUCIBLE",
  "start_url": "./",
  "scope": "./",
  "display": "standalone",
  "background_color": "#070a0f",
  "theme_color": "#070a0f",
  "icons": [
    { "src": "apple-touch-icon.png", "sizes": "180x180", "type": "image/png" }
  ]
}
```

Change `name`, `short_name` and `apple-mobile-web-app-title` per repo, and drop a
180×180 `apple-touch-icon.png` alongside. `start_url` and `scope` are `./` so they
resolve under that project's path.

Each board's own background differs slightly — `#070a0f` (ATLAS), `#080b11`
(CRUCIBLE), `#0a0e12` (GoldenRatio), `#0a0e12` (BTCLiveBoard). Matching
`theme_color` to the page just avoids a one-frame flash on launch.
