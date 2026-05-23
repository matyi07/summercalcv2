# SummerCal v2 - Expo Edition

Private iOS calendar app with AI planning, smart notifications, weather, places, money tracking.

## Quick Start

```bash
npm install
npx expo start
```

## Build IPA

### Prerequisites
1. Expo account: `npx expo login`
2. Apple Developer account ($99/year)
3. iPhone registered in Apple Developer portal

### Build Command
```bash
npx eas build --platform ios --profile production
```

This uploads your code to EAS Build (Expo's cloud service), compiles it on a Mac, and produces an .ipa file. You'll get a link to download the IPA.

### Install on iPhone
1. Download the IPA from the EAS Build link
2. Install via Apple Configurator (Mac) or use a service like Diawi/InstallOnAir

### Development Build (for testing)
```bash
npx eas build --platform ios --profile development
```

## Features
- Today dashboard with weather, next event, free-day suggestions
- Calendar month view with agenda
- Event detail with notes, checklists, links
- AI Day Planner (OpenAI, Claude, DeepSeek, custom endpoints)
- Nearby places search (Google Places or MapKit)
- Weather forecasts (Open-Meteo free API)
- Money/earnings tracker
- Smart notifications (free day, weather, event prep, money)
- Local-first storage (SQLite)
- API keys stored securely in device Keychain

## Tech Stack
- Expo SDK 52
- React Native 0.76
- expo-router (file-based navigation)
- expo-sqlite (local database)
- Zustand (state management)
- date-fns (date utilities)
