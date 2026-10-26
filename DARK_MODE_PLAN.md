# Dark Mode Implementation Plan & Execution for InventoryWatch

## 1. Overview & Goals
Provide complete, polished dark-mode support across both the macOS application (`InventoryWatch`) and the iOS application (`InventoryWatch-iOS`), as well as unit test coverage in `InventoryWatchTests`.
The app supports **System**, **Light**, and **Dark** appearance options:
- **System (Default)**: Automatically tracks macOS and iOS system appearance.
- **Light**: Overrides the app to light appearance regardless of OS setting.
- **Dark**: Overrides the app to dark appearance regardless of OS setting.
- Selection persists across launches via `UserDefaults` (key: `appAppearance`).
- Instantaneous UI update across all windows, sheets, menus, and controls without restart.

---

## 2. Target & Architectural Inspection

### Targets & Schemes
1. **Target `InventoryWatch`** (macOS 14.0+):
   - Scheme: `InventoryWatch`
   - Uses SwiftUI `WindowGroup` (`HiddenTitleBarWindowStyle()`) and `Settings` scene with `SettingsView`.
   - Controls AppKit-level application environment (`NSApp.appearance`).
2. **Target `InventoryWatch-iOS`** (iOS 17.0+):
   - Scheme: `InventoryWatch-iOS`
   - Uses SwiftUI `WindowGroup` with `IOSContentView`, presenting `IOSSettingsView` and `IOSSearchEditView` as sheets.
3. **Target `InventoryWatchTests`** (macOS test bundle):
   - Scheme: `InventoryWatch` test action.
   - Comprehensive unit test suite covering catalogs, model logic, SKU resolution, cooldowns, and preferences.

### Existing Appearance Handling & Color Audit
- Previously, no appearance setting existed; views implicitly used default system color schemes.
- Visual elements audit:
  - `IOSContentView.swift`: Used fixed opacities (`Color.orange.opacity(0.15)`, `Color.red.opacity(0.12)`, `Color.green.opacity(0.15)`, `Color.secondary.opacity(0.15)`). In dark mode, low opacities against dark backgrounds lacked contrast and definition.
  - `ProductAvailabilityList.swift`: Used `Color.blue` for "Order Online" and `Color.green` for pickup quotes.
  - `SettingsView.swift` & `IOSSettingsView.swift`: Had no controls to select appearance.

---

## 3. Implementation Details

### Core Appearance Model (`AppAppearance`)
- Added `AppAppearance` enum in `DefaultsVendor.swift`:
  - Cases: `.system = "system"`, `.light = "light"`, `.dark = "dark"`.
  - Conforms to `String, CaseIterable, Identifiable, Codable`.
  - Maps to SwiftUI `ColorScheme?` (`nil` for system, `.light` for light, `.dark` for dark).
  - macOS bridge: `applyMacOSAppearance()` updates `NSApp.appearance` to `nil`, `NSAppearance(named: .aqua)`, or `NSAppearance(named: .darkAqua)` at runtime.
  - Persisted in `UserDefaults.standard` under key `"appAppearance"`, with property accessor in `DefaultsVendor.appAppearance`. Default is `.system`.

### macOS Implementation (`InventoryWatch`)
- **`InventoryWatchApp.swift`**:
  - Bound `@AppStorage("appAppearance") private var appAppearance: AppAppearance = .system`.
  - Applied `.preferredColorScheme(appAppearance.colorScheme)` to both `ContentView` in `WindowGroup` and `SettingsView` in `Settings`.
  - Added an Appearance menu in the macOS menu bar via `CommandGroup(after: .toolbar)` containing toggle items for System, Light, and Dark.
  - Applied `appAppearance.applyMacOSAppearance()` on initial launch (`.onAppear`) and on setting change (`.onChange(of: appAppearance)`).
- **`SettingsView.swift`**:
  - Added a segmented `Picker("Appearance", selection: $appAppearance)` in `rightControlsView`.
  - Bound `.preferredColorScheme(appAppearance.colorScheme)` to root view.
  - Changes immediately update `NSApp.appearance` and persist across launches.
- **`ContentView.swift`**:
  - Bound `.preferredColorScheme(appAppearance.colorScheme)` and synchronized macOS window appearance.

### iOS Implementation (`InventoryWatch-iOS`)
- **`InventoryWatchiOSApp.swift`**:
  - Bound `@AppStorage("appAppearance") private var appAppearance: AppAppearance = .system`.
  - Applied `.preferredColorScheme(appAppearance.colorScheme)` to the root `IOSContentView`.
- **`IOSContentView.swift`**:
  - Bound `.preferredColorScheme(appAppearance.colorScheme)` to `NavigationStack` and modal sheets (`IOSSettingsView`, `IOSSearchEditView`).
- **`IOSSettingsView.swift`**:
  - Added a dedicated `"Appearance"` section in the `Form` with a segmented picker (`Picker("Appearance", selection: $appAppearance).pickerStyle(.segmented)`) and helpful footer text.
  - Applied `.preferredColorScheme(appAppearance.colorScheme)` to sheet presentations and navigation stack.
- **`IOSSearchEditView.swift`**:
  - Applied `.preferredColorScheme(appAppearance.colorScheme)` to view and store picker sheet.

### Visual Polish & High-Contrast Support
- **Contrast & Badges**:
  - Updated status badges ("Available" / "Unavailable") to use dynamic opacities (`colorScheme == .dark ? 0.25 : 0.15`).
  - Added accessibility outlines using `colorSchemeContrast == .increased` for badges and alert banners.
  - Refined warning and error banner backgrounds for crisp dark appearance without muddy contrast.
- **`ProductAvailabilityList.swift`**:
  - Switched action link color to `.accentColor` with contrast-aware font weights.
  - Pickup availability status text respects `@Environment(\.colorSchemeContrast)`.
  - Retained and respected `useLargeText` and Dynamic Type across all screens.

---

## 4. Test & Build Verification

### Unit Tests (`AppAppearanceTests.swift`)
Implemented test suite in `InventoryWatchTests/AppAppearanceTests.swift`:
1. `allCasesContainsSystemLightDark`: Verifies all 3 enum cases.
2. `displayNamesAreCorrect`: Verifies user-visible strings ("System", "Light", "Dark").
3. `idsMatchRawValues`: Verifies raw string identifiers.
4. `colorSchemeMapping`: Verifies `nil` for `.system`, `.light` for `.light`, and `.dark` for `.dark`.
5. `defaultsVendorAppearancePersistence`: Verifies default `.system`, persistence to `UserDefaults`, and reading through `DefaultsVendor`.
6. `codableEncodingAndDecoding`: Verifies JSON round-trip serialization.
7. `applyMacOSAppearanceDoesNotCrash`: Verifies safe execution of `NSApp.appearance` manipulation on macOS.

### Exact Build & Test Execution Results
1. **Target `InventoryWatch` (macOS)**:
   - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme InventoryWatch -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
   - Result: `** BUILD SUCCEEDED **` (0 errors, 0 warnings).
2. **Target `InventoryWatchTests` (macOS Test Suite)**:
   - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme InventoryWatch -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
   - Result: `** TEST SUCCEEDED **` (All 45 tests passed across 10 test suites, including all 7 `AppAppearanceTests`).
3. **Target `InventoryWatch-iOS` (iOS Simulator)**:
   - Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme InventoryWatch-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
   - Result: `** BUILD SUCCEEDED **` (0 errors, 0 warnings).

---

## 5. Deviations
- None. All requested features, appearance options, persistence, immediate updating, and platform-appropriate controls were implemented following the existing codebase conventions and architecture.
