# iOS Porting Plan for InventoryWatch

## 1. Executive Summary & Goals
This document outlines the architecture, porting strategy, and verification plan for adding a fully functional native iOS application to the existing InventoryWatch macOS repository, targeting the **iPhone 15 Pro Max** (and iOS 17.0+) while keeping the macOS application and its test suites completely intact and working.

---

## 2. Current Project Structure & macOS-Only Discoveries

### Existing Target Structure
- **Target `InventoryWatch`**: macOS Application (macOS 12.0+ deployment target)
- **Target `InventoryWatchTests`**: macOS Unit Test Bundle (macOS 27.0 deployment target)
- **External Dependency**: `Sparkle` 2.10.0 (via Swift Package Manager), used exclusively for macOS auto-updating.

### Discovered macOS-Only APIs & Assumptions
1. **Updater (`Sparkle`)**:
   - `InventoryWatchApp.swift` imports `Sparkle` and initializes `AppUpdater` (`SPUStandardUpdaterController`, `SPUUpdaterDelegate`).
   - `Sparkle` is macOS-only. iOS does not support Sparkle; iOS apps use App Store, TestFlight, or enterprise distribution.
2. **App Lifecycle & Windowing**:
   - `InventoryWatchApp.swift` uses `HiddenTitleBarWindowStyle()`, `CommandGroup` menu bar commands (`.keyboardShortcut("r", modifiers: .command)`), and `Settings { SettingsView() }`.
   - The `Settings` scene is unavailable on iOS (compile-time error on iOS: `'Settings' is only available in macOS 11.0 or newer`).
3. **UI Layout Assumptions**:
   - `ContentView.swift` uses `SettingsLink`, which behaves differently or is not available on iOS for opening a custom modal.
   - Fixed desktop window frames: `.frame(minWidth: 500, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)` and multi-pane desktop layouts in `SettingsView.swift` (`minWidth: 850`).
   - Desktop button styles (`BorderlessButtonStyle()`, `PlainButtonStyle()`).
4. **AppKit Dependencies**:
   - `ProductAvailabilityList.swift` calls `NSWorkspace.shared.open(url)` to open browser URLs. iOS must use `UIApplication.shared.open(url)` or SwiftUI's `@Environment(\.openURL)`.
5. **Background & Polling Model**:
   - macOS allows persistent `Timer.scheduledTimer` in the background because macOS apps are not automatically frozen/suspended when losing focus.
   - iOS strictly suspends background apps unless using background execution modes like `BGTaskScheduler` (`BGAppRefreshTask`). Polling every 1 minute continuously in the background is not permitted by iOS lifecycle policies.
6. **Entitlements & App Sandbox**:
   - `InventoryWatch.entitlements` contains macOS Sandbox exceptions for Mach lookup (`-spks`, `-spki` for Sparkle). These are inappropriate and invalid for iOS targets.

---

## 3. Proposed Xcode Targets, Schemes & Code Organization

### Proposed Xcode Architecture
1. **Keep `InventoryWatch` (macOS)**:
   - Target and scheme remain untouched.
   - Retains Sparkle dependency, macOS windowing, menu commands, and settings scene.
2. **Add `InventoryWatch-iOS`**:
   - Target type: `com.apple.product-type.application` (iOS App)
   - Scheme: `InventoryWatch-iOS`
   - Platform: `iphoneos`, `iphonesimulator`
   - Targeted Device Family: `1` (iPhone) and `2` (iPad)
   - Deployment Target: **iOS 17.0** (iPhone 15 Pro Max shipped with iOS 17.0; enables `ContentUnavailableView`, modern SwiftUI Navigation, and `BackgroundTasks`).
   - No `Sparkle` framework dependency.
   - Code Signing: Set up for local development (`Automatic`, development signing, no hardcoded team IDs or secrets).
3. **Shared Source Files & Resources**:
   - **Core Models & Networking**:
     - `DefaultsVendor.swift` (SearchConfiguration, ProductFamily, DefaultsVendor, LegacyPreferencesMigration)
     - `SKUData.swift`, `SKUDataLoader.swift`, `CatalogTypes.swift`
     - `Countries.swift`, `Helpers.swift`
     - `FulfillmentModel.swift` (Apple pickup API requests, cooldown, rate-limiting, store bootstrapping)
     - `ModelError.swift` (`AppError`)
     - `Analytics.swift`
     - `NotificationSender.swift`, `NotificationManager.swift`
     - `ViewModel.swift`
     - `ModelTypes/*.swift` (`AppleWatchData.swift`, `FulfillmentStore.swift`, `StoreBootstrap.swift`, `PartAvailability.swift`)
     - `JSONCatalog*.swift` (all family catalog resolvers)
   - **Catalogs & Assets**:
     - All 32 international catalog JSON files in `InventoryWatch/Catalogs/`
     - `countries.json`, `Stores_GlobalBootstrap.json`, `Stores_LocalBootstrap.json`
     - `Assets.xcassets` (AccentColor, AppIcon)
4. **Platform-Specific Source Files**:
   - **macOS-specific**:
     - `InventoryWatchApp.swift` (Sparkle updater, macOS window & menu commands)
     - `SettingsView.swift` (Desktop two-column settings layout)
     - `ContentView.swift` (Desktop window content view)
   - **Cross-platform adaptation**:
     - Adapt `ProductAvailabilityList.swift` to use cross-platform URL opening (or environment `openURL`) so it compiles cleanly on both platforms.
   - **iOS-specific** (`InventoryWatch/iOS/`):
     - `InventoryWatchiOSApp.swift`: iOS SwiftUI `@main` entry point with scene lifecycle and background task registration.
     - `IOSContentView.swift`: Native iPhone interface tailored for iPhone 15 Pro Max screen real estate, dynamic Island/safe area, pull-to-refresh, status card, and navigation stack.
     - `IOSSettingsView.swift`: Native grouped iOS Settings form with Search list management, Add/Edit search navigation, store picker, notification preferences, and background refresh explanation.
     - `IOSSearchEditView.swift`: Form for adding/editing saved searches with country, product family, model token, and store selection.
     - `IOSStorePickerView.swift`: Searchable Apple Retail Store picker.
     - `IOSModelPickerView.swift`: Product model picker showing localized names and tokens.
     - `BackgroundRefreshManager.swift`: Handles `BGTaskScheduler` registration, scheduling, and execution with network cooldown checks.
     - `Info.plist`: iOS-specific Info.plist with `UIBackgroundModes` (`fetch`), `BGTaskSchedulerPermittedIdentifiers`, and orientation configuration.

---

## 4. Feature-by-Feature Porting Plan

| Feature | macOS Status | iOS Adaptation | Rationale / Limitations |
| :--- | :--- | :--- | :--- |
| **Multiple Saved Searches** | Supported in `SettingsView` sidebar | Full support in `IOSSettingsView` and main list | Saved searches are stored in `UserDefaults.standard` as JSON `[SearchConfiguration]` and shared directly. |
| **Store Selection & Nearby Stores** | Supported | Full support with searchable store modal & nearby toggle | Uses `fulfillmentModel.loadStoresByCountry` with local bootstrap fallbacks. Displays exact vs. nearby labels. |
| **Refresh Intervals & Manual Refresh** | Supported (Timer) | Foreground Timer + Pull-to-refresh + Manual Button | iOS foreground timer operates when active. Background refresh uses `BGTaskScheduler` with documented OS constraints. |
| **Preferred Model & Notification Filtering** | Supported | Full support | Per-SKU favorite selection in search editor or detail view. Filters out unselected SKUs when toggled. |
| **Custom SKU & Nickname** | Supported | Full support | Configurable in iOS settings, included in pickup query string. |
| **Text Size Settings** | AppStorage `useLargeText` | Full support + Dynamic Type compatibility | Supports user preference toggle while adapting to iPhone screen width. |
| **Inventory Results by Search** | Sectioned `List` | Sectioned Card/List with visual availability status | Clean card hierarchy with availability badges, store pickup quote, and "Order Online" links. |
| **Network Safeguards & Cooldowns** | Supported in `FulfillmentModel` | Reused directly | Cooldown (HTTP 541 / 429 / 503 Retry-After) and rate limiting (3s interval) apply universally. |
| **Catalogs & Local Fallbacks** | Supported in `Bundle.main` | Reused directly | All JSON catalogs compiled into iOS app bundle resources. |
| **Sparkle Updates** | Supported | Unavailable on iOS | Sparkle is omitted from iOS target. iOS builds use standard iOS distribution. |

---

## 5. Data Persistence & Migration Strategy
- **Shared Storage**: Both targets use `UserDefaults.standard` keys:
  - `searchConfigurations`: Encoded `[SearchConfiguration]`
  - `preferredSKUs`: Comma-separated favorite SKUs
  - `preferredCountry`, `preferredStoreNumber`
  - `preferredUpdateInterval`: 0 (Never), 1, 5, 30, 60 minutes
  - `notifyOnlyForPreferredModels`, `showResultsOnlyForPreferredModels`, `shouldIncludeNearbyStores`
  - `customSku`, `customSkuNickname`
  - `lastUpdateDate`: Formatted timestamp
- **Migration**:
  - `LegacyPreferencesMigration` checks domain migration from `com.worthbak.InventoryWatch` to `Bundle.main.bundleIdentifier`. This runs once safely on launch on both platforms.

---

## 6. Background Refresh & Notification Strategy
- **iOS Lifecycle Constraints**:
  - iOS suspends applications shortly after moving to the background. Continuously running a 1-minute `Timer` while backgrounded is impossible without triggering system termination.
- **Implementation Strategy**:
  1. **Foreground**: Active timer (`Timer.scheduledTimer`) respects user interval (1, 5, 30, 60 min).
  2. **Pull-to-refresh & Manual Button**: Allows immediate on-demand inventory fetch.
  3. **Background Tasks**:
     - Register `BGAppRefreshTaskRequest` (`net.brendamour.InventoryWatch.refresh`).
     - Schedule next task upon entering background (`scenePhase == .background`).
     - In task handler: check `pickupCooldown.check()`, run `fulfillmentModel.fetchInventory`, trigger local notification via `NotificationSender`, and call `task.setTaskCompleted(success: true)`.
  4. **Transparency**: The UI informs the user that background updates on iOS occur at system-managed intervals depending on battery, device activity, and charging state.
- **Notifications**:
  - `NotificationManager` uses `UserNotifications.framework` (`UNUserNotificationCenter`).
  - Requests permission on initial setup or first launch.
  - Dedupes notifications within `notificationCooldownHours` (default 6h) to prevent notification fatigue.

---

## 7. Verification of "iPhone Duo" Product Support
- **Catalog Verification**:
  - File inspected: `InventoryWatch/Catalogs/iPhone-Duo-intl.json` (4,141 lines, 33 regions, token `iphone-duo`, generated 2026-10-16).
  - Model names & SKUs verified: Real Apple product metadata (e.g., US SKUs `MK1E4LL/A`, `MK1F4LL/A` in 256GB/512GB Star White and Night Sky).
- **Apple Store Endpoint Verification**:
  - Live endpoint check: `https://www.apple.com/shop/buy-iphone/iphone-duo` returned HTTP 200 with `window.ECHO_CONFIG` node `standard/home/shop_iphone/family/iphone_duo/select`.
- **App Resolver Verification**:
  - `JSONCatalogiPhone.swift` matches `iphone-*.json` files. `iphone-duo` is discovered and parsed under the `.iphone` product family.
  - `ProductFamilyTests.swift` passes assertions: `ProductFamily.iphone.searchDisplayName(modelName: "iPhone Duo") == "iPhone Duo"`.
- **Target Verification**:
  - Ensure the iOS target includes `iPhone-Duo-intl.json` in its Copy Bundle Resources.
  - Verify `iphone-duo` appears in the iOS model selector and loads SKU metadata without errors.

---

## 8. Test & Build Strategy
1. **macOS Target Build & Test**:
   - `xcodebuild test -scheme InventoryWatch -destination 'platform=macOS'` to guarantee zero regressions.
2. **iOS Simulator Build**:
   - `xcodebuild build -scheme InventoryWatch-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' CODE_SIGNING_ALLOWED=NO`
3. **Generic iOS Device Build**:
   - `xcodebuild build -scheme InventoryWatch-iOS -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` to verify arm64 device compatibility.
4. **Unit Test Verification**:
   - Ensure all existing unit tests pass, and add iOS-targeted tests for model and catalog resolution if applicable.

---

## 9. Implementation Status & Verification Results

### Build Verification
- **macOS Target (`InventoryWatch`)**:
  - Build & Test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme InventoryWatch -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
  - Result: **SUCCEEDED** (All 37 test cases passed cleanly, including tests for cooldown, store location formatting, countries JSON, catalog parsing, preferences migration, SKU resolution, and product families).
- **iOS Simulator Target (`InventoryWatch-iOS`)**:
  - Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme InventoryWatch-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' CODE_SIGNING_ALLOWED=NO`
  - Result: **SUCCEEDED** (AppIcon synthesized, all 32 catalog resources bundled, all Swift files compiled cleanly with strict concurrency).
- **Generic iOS Device Target (`InventoryWatch-iOS`)**:
  - Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme InventoryWatch-iOS -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
  - Result: **SUCCEEDED** (Native arm64 iOS binary produced for physical device deployment).

### iPhone Duo Verification
- Validated catalog file `InventoryWatch/Catalogs/iPhone-Duo-intl.json` with 4,141 lines across 33 regions.
- Verified live Apple PDP at `https://www.apple.com/shop/buy-iphone/iphone-duo` returning HTTP 200 with ECHO_CONFIG node `standard/home/shop_iphone/family/iphone_duo/select`.
- Added automated test `SKUResolutionTests/iPhoneDuoSKUDataLoadsAndResolvesSKUs()`, which verified token display name resolution ("iPhone Duo"), SKU lookup (e.g., `MK1E4LL/A`), and localized name generation ("Phone Duo 256GB Star White").
- Verified inclusion in iOS model selector (`IOSSearchEditView`) and catalog resource bundle.

