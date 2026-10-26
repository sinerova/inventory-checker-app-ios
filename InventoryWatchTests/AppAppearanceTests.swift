import Testing
import Foundation
import SwiftUI
@testable import InventoryWatch

struct AppAppearanceTests {

    @Test func allCasesContainsSystemLightDark() {
        let cases = AppAppearance.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.system))
        #expect(cases.contains(.light))
        #expect(cases.contains(.dark))
    }

    @Test func displayNamesAreCorrect() {
        #expect(AppAppearance.system.displayName == "System")
        #expect(AppAppearance.light.displayName == "Light")
        #expect(AppAppearance.dark.displayName == "Dark")
    }

    @Test func idsMatchRawValues() {
        for appearance in AppAppearance.allCases {
            #expect(appearance.id == appearance.rawValue)
        }
    }

    @Test func colorSchemeMapping() {
        #expect(AppAppearance.system.colorScheme == nil, "System appearance should map to nil (inheriting system theme)")
        #expect(AppAppearance.light.colorScheme == .light, "Light appearance should map to .light")
        #expect(AppAppearance.dark.colorScheme == .dark, "Dark appearance should map to .dark")
    }

    @Test func defaultsVendorAppearancePersistence() {
        let defaultsVendor = DefaultsVendor()
        let previous = UserDefaults.standard.string(forKey: "appAppearance")

        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: "appAppearance")
            } else {
                UserDefaults.standard.removeObject(forKey: "appAppearance")
            }
        }

        // Test defaulting to .system when unset
        UserDefaults.standard.removeObject(forKey: "appAppearance")
        #expect(defaultsVendor.appAppearance == .system)

        // Test setting light
        defaultsVendor.appAppearance = .light
        #expect(UserDefaults.standard.string(forKey: "appAppearance") == AppAppearance.light.rawValue)
        #expect(defaultsVendor.appAppearance == .light)

        // Test setting dark
        defaultsVendor.appAppearance = .dark
        #expect(UserDefaults.standard.string(forKey: "appAppearance") == AppAppearance.dark.rawValue)
        #expect(defaultsVendor.appAppearance == .dark)

        // Test setting system
        defaultsVendor.appAppearance = .system
        #expect(UserDefaults.standard.string(forKey: "appAppearance") == AppAppearance.system.rawValue)
        #expect(defaultsVendor.appAppearance == .system)
    }

    @Test func codableEncodingAndDecoding() throws {
        for appearance in AppAppearance.allCases {
            let encoded = try JSONEncoder().encode(appearance)
            let decoded = try JSONDecoder().decode(AppAppearance.self, from: encoded)
            #expect(decoded == appearance)
        }
    }

    #if os(macOS)
    @Test @MainActor func applyMacOSAppearanceDoesNotCrash() {
        // Ensure calling applyMacOSAppearance executes cleanly for each choice
        AppAppearance.system.applyMacOSAppearance()
        AppAppearance.light.applyMacOSAppearance()
        AppAppearance.dark.applyMacOSAppearance()
        AppAppearance.system.applyMacOSAppearance()
    }
    #endif
}
