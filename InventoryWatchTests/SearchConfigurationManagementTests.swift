import Testing
import Foundation
@testable import InventoryWatch

struct SearchConfigurationManagementTests {

    @Test @MainActor func searchConfigurationsBatchDeletionSafelyDeletesMultipleOffsets() {
        let defaults = UserDefaults.standard
        let savedSearches = defaults.object(forKey: "searchConfigurations")
        defer { defaults.set(savedSearches, forKey: "searchConfigurations") }

        let s1 = SearchConfiguration(family: .iphone, token: "iphone-17", countryCode: "US", storeNumber: "R001")
        let s2 = SearchConfiguration(family: .watch, token: "apple-watch", countryCode: "US", storeNumber: "R002")
        let s3 = SearchConfiguration(family: .mac, token: "macbook-air", countryCode: "CA", storeNumber: "R003")

        defaults.set(try? JSONEncoder().encode([s1, s2, s3]), forKey: "searchConfigurations")
        let model = ViewModel()
        #expect(model.searchConfigurations.count == 3)

        // Delete first and third items
        model.removeSearchConfigurations(at: IndexSet([0, 2]))
        #expect(model.searchConfigurations.count == 1)
        #expect(model.searchConfigurations.first?.id == s2.id)
    }

    @Test @MainActor func searchConfigurationsReorderingUpdatesOrderAndPersists() throws {
        let defaults = UserDefaults.standard
        let savedSearches = defaults.object(forKey: "searchConfigurations")
        defer { defaults.set(savedSearches, forKey: "searchConfigurations") }

        let s1 = SearchConfiguration(family: .iphone, token: "iphone-17", countryCode: "US", storeNumber: "R001")
        let s2 = SearchConfiguration(family: .watch, token: "apple-watch", countryCode: "US", storeNumber: "R002")

        defaults.set(try? JSONEncoder().encode([s1, s2]), forKey: "searchConfigurations")
        let model = ViewModel()
        #expect(model.searchConfigurations.map(\.id) == [s1.id, s2.id])

        // Move s1 to after s2
        model.moveSearchConfigurations(from: IndexSet(integer: 0), to: 2)
        #expect(model.searchConfigurations.map(\.id) == [s2.id, s1.id])

        // Verify persistence
        let persistedData = try #require(defaults.data(forKey: "searchConfigurations"))
        let decoded = try JSONDecoder().decode([SearchConfiguration].self, from: persistedData)
        #expect(decoded.map(\.id) == [s2.id, s1.id])
    }

    @Test func catalogMemoryCacheReturnsConsistentData() {
        let cache = CatalogMemoryCache.shared
        let files = cache.files(for: "iphone")
        #expect(files.isEmpty == false, "Should find iPhone catalog JSON files")

        if let firstURL = files.first {
            let root1 = cache.root(for: firstURL)
            let root2 = cache.root(for: firstURL)
            #expect(root1 != nil, "CatalogRoot should parse")
            #expect(root1?.discovered_models?.isEmpty == false || root1?.country_mappings?.isEmpty == false)
            #expect(root2 != nil)
        }
    }
}
