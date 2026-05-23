# SummerCal v2 — Build Instructions

## Prerequisites

- **Mac** with macOS 14 (Sonoma) or later
- **Xcode 15** or later (App Store or [developer.apple.com](https://developer.apple.com))
- **XcodeGen** — `brew install xcodegen`
- **Apple Developer account** ($99/year) or free personal team for ad-hoc

## Step 1 — Register Your iPhone UDID

1. Connect your iPhone to the Mac via USB.
2. On the iPhone go to **Settings > General > About** and tap the serial number to reveal the UDID. Copy it.
3. Go to [developer.apple.com/account/resources/devices](https://developer.apple.com/account/resources/devices). Add the UDID as a new device.

## Step 2 — Set the Development Team

1. Open the project in Xcode (run `make project` first, or `xcodegen generate`).
2. Select the **SummerCal** target.
3. In the **Signing & Capabilities** tab, choose your Team from the dropdown.
4. Close Xcode.

## Step 3 — Build the IPA

From the repo root:

```bash
./build.sh
```

Or via Make:

```bash
make ipa
```

The IPA will be at `build/export/SummerCal.ipa`.

## Step 4 — Install on iPhone

### Option A — build script (auto)

```bash
./build.sh --install
```

This detects your connected iPhone and installs the IPA via `devicectl`.

### Option B — Apple Configurator

1. Install [Apple Configurator](https://apps.apple.com/app/apple-configurator/id1037126344) from the Mac App Store.
2. Connect the iPhone and drag `build/export/SummerCal.ipa` onto the device.

### Option C — Xcode Devices Window

1. Open Xcode and go to **Window > Devices and Simulators**.
2. Select your connected iPhone.
3. Drag the IPA file onto the installed apps list.

---

## Alternative Build Methods

### GitHub Actions CI

The repository includes a workflow at `.github/workflows/build-ipa.yml`. The IPA is built on every push to `main` and uploaded as a workflow artifact.

**Setup:**
1. In your GitHub repo go to **Settings > Secrets and variables > Actions**.
2. Add a secret named `DEVELOPMENT_TEAM` with your Apple Team ID (find it at [developer.apple.com/account](https://developer.apple.com/account) — it's the alphanumeric string next to your team name).

The workflow uses `macos-latest` (Apple Silicon) and handles `xcodegen` install, project generation, archiving, and IPA export automatically.

### Cloud Mac Services

If you don't have a Mac:

- **[MacStadium](https://www.macstadium.com)** — dedicated Mac mini / Mac Pro in the cloud
- **[MacinCloud](https://www.macincloud.com)** — hourly or monthly remote Mac access
- **[GitHub Actions](https://github.com/features/actions)** — free macOS runners (sealed above)

Clone the repo on any of these and follow **Step 3**.
