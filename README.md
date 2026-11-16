# Capacitor SystemBars: 3-button navigation bar scrim missing since 8.5.2

This is a minimal repro for an Android regression in `@capacitor/android` 8.5.2 and later; 8.5.1 is fine.

With 3-button navigation, the navigation bar no longer gets its translucent contrast scrim, and web content shows unprotected behind the back, home and recents buttons. On windows that are not edge-to-edge (Android 14 and older without `EdgeToEdge.enable`), the navigation bar also loses its normal opaque background.

The app is the default `npx cap add android` template, except for `www/index.html`:
- the page uses `viewport-fit=cover`;
- alternating dark and light rows show whether there is a scrim behind the navigation buttons;
- a box at the top prints `env(safe-area-inset-*)`, `--safe-area-inset-*` and `window.innerHeight`, to check that the fix leaves insets unchanged.

## Run it

You need an emulator or device with 3-button navigation. Emulators default to gesture navigation; to switch, run `adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton` and `adb shell cmd overlay disable com.android.internal.systemui.navbar.gestural`.

```sh
npm install
npx cap sync android
npx cap run android          # 8.6.0, no scrim

./apply-fix.sh               # applies systembars-scrim-fix.patch to node_modules/@capacitor/android
npx cap sync android
npx cap run android          # 8.6.0 + fix, scrim is back
```

To compare with 8.5.1, run `npm i -E @capacitor/android@8.5.1 && npx cap sync android && npx cap run android`.

To test with `EdgeToEdge.enable(this)`, which the SystemBars docs recommend on Android 14 and older, add it to `MainActivity.onCreate` after `super.onCreate(savedInstanceState)`.

## Results

Tested on Android 16 (API 36, WebView 156) and Android 14 (API 34, WebView 157) emulators with 3-button navigation. The table gives the navigation bar pixel over the page content:

| Setup | 8.5.1 | 8.6.0 | 8.6.0 + fix |
|---|---|---|---|
| API 36, default template | scrim | **no scrim** | scrim |
| API 36, `EdgeToEdge.enable` | scrim | **no scrim** | scrim |
| API 34, `EdgeToEdge.enable` | scrim | **no scrim** | scrim |
| API 34, default template (not edge-to-edge) | black navigation bar | **light grey bar** | black navigation bar |

With the fix, the screenshots below the status bar are pixel-identical to 8.5.1 on API 36, in both setups.

The page sees the same insets with the fix as without it in every edge-to-edge setup:

| Setup | `env()` top/bottom | `--safe-area-inset-*` top/bottom | `innerHeight` |
|---|---|---|---|
| API 36, both setups | 49 / 48 px | 48 / 48 px | 914 |
| API 34, `EdgeToEdge.enable` | 50 / 48 px | 49 / 48 px | 872 |

For API 34 without edge-to-edge, the fix brings back the 8.5.1 layout: the WebView ends at the navigation bar, and the bar is opaque again.

![API 36](screenshots/api36-navbar.png)
![API 36 with EdgeToEdge.enable](screenshots/api36-edgetoedge-navbar.png)
![API 34 with EdgeToEdge.enable](screenshots/api34-edgetoedge-navbar.png)
![API 34 not edge-to-edge](screenshots/api34-navbar.png)

## Cause

Since 8.5.2 (e37d9c6), `SystemBars.initWindowInsetsListener()` registers its `OnApplyWindowInsetsListener` on `getWindow().getDecorView()`. 8.5.1 registered it on the WebView's parent.

A listener is called *instead of* the view's own `onApplyWindowInsets`. For the DecorView, that method lays out the system bar backgrounds, including the navigation bar contrast scrim. The Android reference for `View.OnApplyWindowInsetsListener` says: "The listener may optionally call the parameter View's `onApplyWindowInsets` method to apply the View's normal behavior as part of its own."

## Fix

`systembars-scrim-fix.patch` calls the DecorView's own `onApplyWindowInsets` first and continues with the insets it returns.
