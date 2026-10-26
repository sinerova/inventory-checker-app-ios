//
//  Helpers.swift
//  InventoryWatch
//
//  Created by Worth Baker on 3/19/22.
//

import Foundation

typealias SKUString = String
typealias CountryCode = String

extension Array where Element == String {
  func sortedNumerically() -> [Element] {
    sorted { lhs, rhs in
      lhs.compare(rhs, options: [.numeric], locale: .current) == .orderedAscending
    }
  }
}

func compareNumeric(_ version1: String, _ version2: String) -> ComparisonResult {
  return version1.compare(version2, options: .numeric)
}

enum StoreLocationFormatter {
    static func storeLocationLabel(store: RetailStore?, storeNumber: String, includeNearbyStores: Bool) -> String {
        guard !storeNumber.isEmpty else { return "No store selected" }
        let relation = includeNearbyStores ? "Near" : "At"
        guard let store else { return "\(relation) selected store (\(storeNumber))" }
        let name = store.name.hasPrefix("Apple ") ? store.name : "Apple \(store.name)"
        let location = store.address.cityStateDisplay
        return location.isEmpty ? "\(relation) \(name)" : "\(relation) \(name) — \(location)"
    }
}



