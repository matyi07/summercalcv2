# Install SummerCal on iPhone (Windows, No Developer Account)

This guide uses **Sideloadly** on Windows to sign and install the IPA with your free Apple ID.

## Step 1: Get the unsigned IPA

**Option A: Download from GitHub Actions**
1. Go to your GitHub repo → Actions → "Build Unsigned IPA" workflow
2. Click the latest successful run
3. Download the "SummerCal-unsigned-IPA" artifact

**Option B: Build locally on a Mac**
If you can borrow a Mac for 30 minutes:
```bash
cd SummerCalExpo
npm install
npx expo run:ios --device
```
This installs directly to your iPhone with a free Apple ID. No IPA needed.

## Step 2: Install Sideloadly on Windows

1. Download Sideloadly from [sideloadly.io](https://sideloadly.io)
2. Install and launch it
3. Connect your iPhone to your Windows PC via USB cable
4. Unlock your iPhone and tap "Trust This Computer"

## Step 3: Sign and Install the IPA

1. Open Sideloadly
2. Drag `SummerCal-unsigned.ipa` into the Sideloadly window
3. Enter your free Apple ID email (create one at appleid.apple.com if needed)
4. Click "Start"
5. Enter your Apple ID password when prompted
6. Wait for signing and installation to complete

## Step 4: Trust the Developer Certificate

After installation, the app won't open immediately:
1. On your iPhone, go to **Settings → General → VPN & Device Management**
2. Tap your Apple ID email under "Developer App"
3. Tap **Trust**
4. The app will now open

## Important Notes

- **The app expires after 7 days.** You need to re-sign and re-install it weekly.
- Sideloadly has an "Auto-Refresh" option that re-signs automatically when your iPhone is connected via USB/WiFi.
- **Alternative: AltStore** — similar process, uses AltServer on Windows. Download from [altstore.io](https://altstore.io).
- You can use any free Apple ID (no credit card required, create one at appleid.apple.com).

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "App not trusted" | Go to Settings → General → VPN & Device Management → Trust |
| "Maximum app IDs reached" | Free Apple IDs allow 3 sideloaded apps. Remove unused ones. |
| "Certificate expired" | Re-install via Sideloadly — it refreshes the certificate. |
| App crashes on launch | The unsigned IPA may have issues. Try re-building. |
| "This app cannot be installed" | Ensure your iPhone is on iOS 16+ and has enough storage (~200MB free). |
