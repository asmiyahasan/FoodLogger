# Development guide

## Setup

1. **Xcode 27** on an Apple silicon Mac.
2. Open `FoodLogger.xcodeproj`. It uses Xcode's folder-synchronised format, so any file added inside `FoodLogger/` is included in the app automatically.
3. **API keys:** copy `Secrets.example.plist` to `FoodLogger/Secrets.plist` and fill in:
   - `claudeAPIKey`, from [console.anthropic.com](https://console.anthropic.com) (required for photo + voice logging)
   - `usdaAPIKey`, from [fdc.nal.usda.gov](https://fdc.nal.usda.gov/api-key-signup) (optional)

   `Secrets.plist` is git-ignored. Keys entered in the app's Settings are stored in the Keychain instead and take priority (`APIKeys.value(for:)`).
4. **Signing:** set your own team and bundle identifier under *Signing & Capabilities*.

## Running on an iPhone

- Select the phone, press **Run**. The first run copies debug symbols to the phone and can take several minutes.
- Turn on **Developer Mode** (Settings → Privacy & Security) and trust your developer certificate (Settings → General → VPN & Device Management).
- After the first cable pairing, Xcode can install over Wi-Fi.

### Free developer accounts

Apps signed with a free account expire after **7 days**. Re-running from Xcode renews them and keeps all data. `AppExpiry` reads the expiry date from the app's embedded provisioning profile, schedules a notification the day before, and shows a banner on Today in the last two days.

Free accounts can't use iCloud (CloudKit) or push notifications, which is why sync isn't enabled yet. The SwiftData models already follow CloudKit's rules.

## Tests

`FoodLoggerTests/NutrientsTests.swift` (Swift Testing) covers nutrient scaling and totals, kJ/kcal conversion, meal-type inference and macro calculation. Run with **⌘U** on a simulator.

## Tools

### Rebuilding the Australian food database

```sh
pip install openpyxl
python3 Tools/convert_afcd.py "Data/AFCD Release 3 - Nutrient profiles.xlsx"
```

Download the *Nutrient profiles* Excel file from [FSANZ](https://www.foodstandards.gov.au/science-data/food-nutrient-databases/afcd) into `Data/` (git-ignored). The script finds columns by header name and writes `FoodLogger/Resources/afcd.json`. Each food is stored as `{"id", "name", "n": [kcal, protein, fat, saturated fat, carbs, sugars, fibre, sodium mg]}` per 100 g.

### Regenerating the app icon

`Tools/make_app_icon.py` draws the icon from SVG (needs `rsvg-convert` and Pillow). Sources are in `Design/AppIcon/`. It produces light, dark and tinted iOS icons plus macOS sizes.

## Conventions

- **Settings:** add new keys to `SettingsKey`, with defaults in `GoalDefaults`. If a setting should survive a restore, add it to `SettingsKey.backedUp`.
- **Model changes:** give every new property a default value, keep relationships optional, and avoid `@Attribute(.unique)`. That keeps lightweight migration and future CloudKit sync working.
- **Backup format:** add new fields to `BackupFile` records as optionals, so older backups still decode.
- **Imports:** the project enables *member import visibility*, so each file must import every module it uses (for example `import SwiftData` for `modelContext`, `import Vision` for barcode symbologies).
- **Concurrency:** code is main-actor by default. Mark types `nonisolated` when they're used off the main thread or need `Codable`/`Sendable` conformances.
- **Colours:** use `Theme` (turquoise for brand and water, orange for calories, deep orange for attention). Light and dark values live in `Assets.xcassets`.
- **iPhone-only APIs:** wrap them in `#if os(iOS)`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "Unable to log in with account" when building | Xcode → Settings → Accounts: remove and re-add your Apple ID; accept the agreement at developer.apple.com |
| App installs but nothing opens | Unlock the phone; trust the developer certificate; wait for "Extracting OS library symbols" to finish |
| "…not available due to missing import of defining module" | Add the named `import` to that file |
| Siri doesn't recognise a phrase | Wait a few minutes after installing, or run the shortcut once from the Shortcuts app |
| Analysis fails with an API error | Check the Claude key and credit balance |
