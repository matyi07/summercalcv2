# Install SummerCal via AltStore (Windows)

AltStore is an alternative app store that signs IPAs with your free Apple ID. Once set up, it auto-refreshes the app over WiFi so you don't need to manually re-install every 7 days.

## Initial Setup (One Time)

1. **Download AltServer for Windows** from [altstore.io](https://altstore.io)
2. Install and launch AltServer (it runs in the system tray)
3. Connect your iPhone via USB cable
4. In AltServer tray icon: **Install AltStore → Your iPhone**
5. Enter your free Apple ID and password
6. **AltStore** app appears on your iPhone home screen
7. On iPhone: Settings → General → VPN & Device Management → Trust the certificate

## Installing SummerCal

1. Download `SummerCal-unsigned.ipa` from GitHub Actions (or build it)
2. Transfer the IPA to your iPhone (via iCloud Drive, AirDrop, or iTunes file sharing)
3. Open the AltStore app on your iPhone
4. Go to **My Apps** tab
5. Tap the **+** button in the top-left
6. Select `SummerCal-unsigned.ipa`
7. Enter your Apple ID password if prompted
8. Wait for installation

## Auto-Refresh (Keep App Alive)

AltStore automatically refreshes app certificates in the background when:
- Your iPhone is on the same WiFi as your Windows PC running AltServer
- The app is within 24 hours of expiring

No manual re-install needed! Just keep AltServer running on your PC.

## App ID Limit

Free Apple IDs allow **3 sideloaded apps** maximum (including AltStore itself). So you have room for 2 more apps.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "AltStore is not available" | AltServer must be running on your PC. Connect to same WiFi. |
| "Could not find AltServer" | Ensure Bonjour/mDNS is enabled (iTunes installs this). |
| App expired | Open AltStore → My Apps → tap "Refresh All" while AltServer is running. |
