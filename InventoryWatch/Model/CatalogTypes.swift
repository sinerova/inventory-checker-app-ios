//
//  CatalogTypes.swift
//  InventoryWatch
//
//  Created by Worth Baker on 10/25/22.
//

import Foundation

struct AWLocalization: Codable { let token_display: [String: String]? }

protocol CategoryResolver {
    @MainActor func productURL(for partNumber: String, country: Country) -> URL?
}

struct ProductMetadata: Codable {
    let name: String
    let colorKey: String
    let colorDisplay: String
    let capacity: String
    let family: String
    let familyName: String?
    let urlSlug: String?
    let price: Double?
    let partNumber: String?
    let metadata: DeviceMetadata?
}

struct DeviceMetadata: Codable {
    let caseSize: String?
    let caseMaterial: String?
    let connectivity: String?
    let color: String?
    let isRealPartNumber: Bool?
    let urlFormat: [String: String]?
    let sourcePage: String?
}

struct CatalogNode: Codable {
    let url: String?
    let skus: [String: ProductMetadata]?
}

struct CatalogCountryMap: Codable {
    let shop_paths: [String: String]?
    let localization: AWLocalization?
}

struct CatalogRoot: Codable {
    let discovered_models: [String: [String: CatalogNode]]?
    let country_mappings: [String: CatalogCountryMap]?
}

final class CatalogMemoryCache: @unchecked Sendable {
    static let shared = CatalogMemoryCache()
    private var cache: [URL: CatalogRoot] = [:]
    private var fileListCache: [String: [URL]] = [:]
    private let lock = NSLock()

    private init() {}

    func files(for prefix: String) -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        if let cached = fileListCache[prefix] {
            return cached
        }
        let candidates = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let matched = candidates.filter { url in
            let name = url.deletingPathExtension().lastPathComponent
            let lc = name.lowercased()
            return lc.hasPrefix(prefix) && lc.hasSuffix("-intl")
        }
        fileListCache[prefix] = matched
        return matched
    }

    func root(for url: URL) -> CatalogRoot? {
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[url] {
            return existing
        }
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CatalogRoot.self, from: data) else {
            return nil
        }
        cache[url] = decoded
        return decoded
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        fileListCache.removeAll()
    }
}

protocol CategoryCatalog {
    static var filePrefix: String { get }
}

extension CategoryCatalog {
    @MainActor static func modelJSONFiles() -> [URL] {
        CatalogMemoryCache.shared.files(for: filePrefix)
    }

    @MainActor static func categoriesSourcePages(for country: Country) -> [String] {
        var tokens: Set<String> = []
        let lc = country.shortcode.lowercased()
        let uc = country.shortcode.uppercased()
        for url in modelJSONFiles() {
            guard let root = CatalogMemoryCache.shared.root(for: url) else { continue }
            if let byCountry = root.discovered_models?[lc] ?? root.discovered_models?[uc] {
                for (token, _) in byCountry { tokens.insert(token) }
            }
        }
        return Array(tokens).sorted()
    }

    @MainActor static func tokenDisplayName(for country: Country, sourcePage: String) -> String? {
        let lc = country.shortcode.lowercased()
        let uc = country.shortcode.uppercased()
        for url in modelJSONFiles() {
            guard let root = CatalogMemoryCache.shared.root(for: url) else { continue }
            if let name = root.country_mappings?[lc]?.localization?.token_display?[sourcePage] { return name }
            if let name = root.country_mappings?[uc]?.localization?.token_display?[sourcePage] { return name }
        }
        return nil
    }

    @MainActor static func categoryData(for country: Country, sourcePage: String) -> [String: ProductMetadata]? {
        let lc = country.shortcode.lowercased()
        let uc = country.shortcode.uppercased()
        for url in modelJSONFiles() {
            guard let root = CatalogMemoryCache.shared.root(for: url) else { continue }
            if let byCountry = root.discovered_models?[lc] ?? root.discovered_models?[uc],
               let node = byCountry[sourcePage], let skus = node.skus, skus.isEmpty == false {
                return skus
            }
        }
        return nil
    }

    @MainActor static func metadata(for sku: String, country: Country) -> ProductMetadata? {
        let lc = country.shortcode.lowercased()
        let uc = country.shortcode.uppercased()
        for url in modelJSONFiles() {
            guard let root = CatalogMemoryCache.shared.root(for: url) else { continue }
            if let byCountry = root.discovered_models?[lc] ?? root.discovered_models?[uc] {
                for (_, node) in byCountry { if let md = node.skus?[sku] { return md } }
            }
        }
        return nil
    }

    @MainActor static func pdpBaseURL(for country: Country, sourcePage token: String) -> URL? {
        let lc = country.shortcode.lowercased()
        let uc = country.shortcode.uppercased()
        for url in modelJSONFiles() {
            guard let root = CatalogMemoryCache.shared.root(for: url) else { continue }
            if let byCountry = root.discovered_models?[lc] ?? root.discovered_models?[uc],
               let node = byCountry[token], let nodeURL = node.url, let u = URL(string: nodeURL) { return u }
            if let cm = root.country_mappings?[lc] ?? root.country_mappings?[uc], let path = cm.shop_paths?[token] {
                let full = "https://www.apple.com/\(lc)/\(path)"
                if let u = URL(string: full) { return u }
            }
        }
        return nil
    }
}