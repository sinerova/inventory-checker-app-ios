import Testing
import Foundation
@testable import InventoryWatch

struct SKUResolutionTests {

    @Test func watchSKUDataReturnsNonNilForValidTokenAndUS() async throws {
        let loader = SKUDataLoader()
        let us = Country(name: "United States", shortcode: "US", locale: "en_US", skuCode: "LL")
        let result = await loader.watchSKUData(forToken: "apple-watch", country: us)
        #expect(result != nil, "watchSKUData should return non-nil for valid token plus US combo")
    }

    @Test func watchSKUDataReturnsNilForInvalidToken() async throws {
        let loader = SKUDataLoader()
        let us = Country(name: "United States", shortcode: "US", locale: "en_US", skuCode: "LL")
        let result = await loader.watchSKUData(forToken: "nonexistent-token-xyz", country: us)
        #expect(result == nil, "watchSKUData should return nil for invalid token")
    }

    @Test func buildLocalizedProductNameProducesNonEmptyForKnownSKUs() async throws {
        let loader = SKUDataLoader()
        let us = Country(name: "United States", shortcode: "US", locale: "en_US", skuCode: "LL")
        guard let data = await loader.watchSKUData(forToken: "apple-watch", country: us),
              let firstSKU = data.orderedSKUs.first else {
            return
        }
        let name = data.productName(forSKU: firstSKU) ?? ""
        #expect(name.isEmpty == false, "buildLocalizedProductName should produce non-empty string")
    }

    @Test @MainActor func iPhoneDuoSKUDataLoadsAndResolvesSKUs() async throws {
        let loader = SKUDataLoader()
        let us = Country(name: "United States", shortcode: "US", locale: "en_US", skuCode: "LL")
        
        let tokenDisplayName = JSONCatalogiPhone.tokenDisplayName(for: us, sourcePage: "iphone-duo")
        #expect(tokenDisplayName == "iPhone Duo")
        
        guard let data = loader.phoneSKUData(forToken: "iphone-duo", country: us) else {
            Issue.record("iPhone Duo SKUData could not be loaded for US")
            return
        }
        
        #expect(data.orderedSKUs.isEmpty == false, "iPhone Duo should have discovered SKUs in US catalog")
        #expect(data.orderedSKUs.contains("MK1E4LL/A"), "MK1E4LL/A should be present in iPhone Duo US catalog")
        
        if let productName = data.productName(forSKU: "MK1E4LL/A") {
            #expect(productName.contains("Duo"), "Product name should identify Duo family")
            #expect(productName.contains("256GB"), "Product name should include capacity")
            #expect(productName.contains("Star White"), "Product name should include color")
        } else {
            Issue.record("Product name was nil for MK1E4LL/A")
        }
    }
}