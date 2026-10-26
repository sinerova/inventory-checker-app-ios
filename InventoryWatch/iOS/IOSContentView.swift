//
//  IOSContentView.swift
//  InventoryWatch
//

import SwiftUI

struct IOSContentView: View {
    @EnvironmentObject var model: ViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    @AppStorage("lastUpdateDate") private var lastUpdateDate: String = ""
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    @AppStorage("shouldIncludeNearbyStores") private var shouldIncludeNearbyStores: Bool = true
    @AppStorage("showResultsOnlyForPreferredModels") private var showResultsOnlyForPreferredModels: Bool = false
    @AppStorage("preferredSKUs") private var preferredSKUsCSV: String = ""
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    
    @State private var storesByCountry: [String: [RetailStore]] = [:]
    @State private var isShowingSettings: Bool = false
    @State private var isShowingAddSearch: Bool = false
    
    private var preferredSKUsSet: Set<String> {
        Set(preferredSKUsCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Status & Error Banners
                if let error = model.errorState {
                    Section {
                        errorBanner(for: error)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                if model.pickupErrorKeys.isEmpty == false {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Apple pickup API warning: \(model.pickupErrorKeys.joined(separator: ", "))")
                                .font(.footnote)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.orange.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(colorSchemeContrast == .increased ? 0.6 : 0), lineWidth: 1)
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - Empty State
                if model.searchConfigurations.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                "No Searches Configured",
                                systemImage: "magnifyingglass",
                                description: Text("Add a product and Apple Store to monitor in-store pickup availability.")
                            )
                            Button {
                                isShowingAddSearch = true
                            } label: {
                                Label("Add Search", systemImage: "plus")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 24)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    // MARK: - Search Results
                    ForEach(model.searchConfigurations) { search in
                        searchSection(for: search)
                    }
                }
                
                // MARK: - Footer Info
                if !model.searchConfigurations.isEmpty {
                    Section {
                        footerView
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("InventoryWatch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSearch = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Search")
                    
                    Button {
                        Task { await model.fetchLatestInventory() }
                    } label: {
                        if model.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isLoading)
                    .accessibilityLabel(model.isLoading ? "Refreshing Inventory" : "Refresh Inventory")
                }
            }
            .refreshable {
                await model.fetchLatestInventory()
            }
            .sheet(isPresented: $isShowingSettings) {
                IOSSettingsView()
                    .environmentObject(model)
                    .preferredColorScheme(appAppearance.colorScheme)
            }
            .sheet(isPresented: $isShowingAddSearch) {
                IOSSearchEditView { newConfig in
                    model.addSearchConfiguration(newConfig)
                }
                .environmentObject(model)
                .preferredColorScheme(appAppearance.colorScheme)
            }
            .preferredColorScheme(appAppearance.colorScheme)
            .onAppear {
                Task {
                    await model.fetchLatestInventory()
                    NotificationManager.shared.requestNotificationPermissions()
                }
            }
            .task(id: Set(model.searchConfigurations.filter { !$0.storeNumber.isEmpty }.map(\.countryCode))) {
                let countryCodes = Set(model.searchConfigurations.filter { !$0.storeNumber.isEmpty }.map(\.countryCode))
                for countryCode in countryCodes.sorted() {
                    let stores = await model.stores(for: countryCode)
                    guard !Task.isCancelled else { return }
                    storesByCountry[countryCode] = stores
                }
            }
        }
    }
    
    // MARK: - Error Banner
    @ViewBuilder
    private func errorBanner(for error: AppError) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text(error.errorMessage)
                    .font(.footnote)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(colorScheme == .dark ? 0.22 : 0.12))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(colorSchemeContrast == .increased ? 0.6 : 0), lineWidth: 1)
        )
    }
    
    // MARK: - Search Section
    @ViewBuilder
    private func searchSection(for search: SearchConfiguration) -> some View {
        let country = Countries[search.countryCode] ?? USData
        let title = searchTitle(for: search, country: country)
        let store = storesByCountry[search.countryCode]?.first { $0.storeNumber == search.storeNumber }
        let storeLabel = StoreLocationFormatter.storeLocationLabel(
            store: store,
            storeNumber: search.storeNumber,
            includeNearbyStores: shouldIncludeNearbyStores
        )
        
        let result = model.searchResults.first { $0.id == search.id }
        let availableParts = result?.availableParts ?? []
        let availableSkus = Set(availableParts.flatMap { $0.1.map(\.partNumber) })
        let pickupInfo = availableParts.reduce(into: [String: (count: Int, quote: String?)]()) { res, entry in
            for part in entry.1 where part.availability == .available {
                let curr = res[part.partNumber] ?? (0, nil)
                res[part.partNumber] = (curr.count + 1, curr.quote ?? part.availabilityStorePickupQuote)
            }
        }
        
        let displayedPreferredSKUs: Set<String> = showResultsOnlyForPreferredModels ? preferredSKUsSet : []
        
        Section {
            // Header information card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(useLargeText ? .title2.bold() : .headline)
                        Text("\(country.name) • \(storeLabel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if result == nil && model.isLoading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Checking")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.secondary.opacity(colorSchemeContrast == .increased ? 0.5 : 0), lineWidth: 1)
                        )
                    } else if availableSkus.isEmpty {
                        Label("Unavailable", systemImage: "xmark.circle")
                            .font(.caption2.bold())
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(colorScheme == .dark ? 0.25 : 0.15))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(colorSchemeContrast == .increased ? 0.5 : 0), lineWidth: 1)
                            )
                    } else {
                        Label("\(availableSkus.count) Available", systemImage: "checkmark.circle.fill")
                            .font(.caption2.bold())
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(colorScheme == .dark ? 0.25 : 0.15))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.green.opacity(colorSchemeContrast == .increased ? 0.6 : 0), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.vertical, 4)
            
            // Availability Items
            if result == nil && model.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking in-store availability…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ProductAvailabilityList(
                    country: country,
                    token: search.token,
                    emptyTokenMessage: "No token configured.",
                    skuData: skuData(for: search, country: country),
                    availableSkus: availableSkus,
                    pickupInfo: pickupInfo,
                    preferredSKUs: displayedPreferredSKUs,
                    productURL: { partNumber in
                        productURL(for: search, partNumber: partNumber, country: country)
                    },
                    categoryURL: {
                        categoryURL(for: search, country: country)
                    },
                    showPDPPreview: false
                )
            }
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        VStack(alignment: .center, spacing: 6) {
            if !lastUpdateDate.isEmpty {
                Text("Last updated: \(lastUpdateDate)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            if showResultsOnlyForPreferredModels {
                Text("Filtered to favorite models only")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    private func searchTitle(for search: SearchConfiguration, country: Country) -> String {
        let tokenName: String?
        switch search.family {
        case .iphone:
            tokenName = JSONCatalogiPhone.tokenDisplayName(for: country, sourcePage: search.token)
        case .watch:
            tokenName = JSONCatalogAppleWatch.tokenDisplayName(for: country, sourcePage: search.token)
        case .mac:
            tokenName = JSONCatalogMac.tokenDisplayName(for: country, sourcePage: search.token)
        case .ipad:
            tokenName = JSONCatalogiPad.tokenDisplayName(for: country, sourcePage: search.token)
        case .airpods:
            tokenName = JSONCatalogAirPods.tokenDisplayName(for: country, sourcePage: search.token)
        case .homepod:
            tokenName = JSONCatalogHomePod.tokenDisplayName(for: country, sourcePage: search.token)
        case .avp:
            tokenName = JSONCatalogAVP.tokenDisplayName(for: country, sourcePage: search.token)
        }
        let modelTitle = tokenName ?? search.family.searchDisplayName(modelName: search.token)
        return search.family.searchDisplayName(modelName: modelTitle)
    }
    
    private func skuData(for search: SearchConfiguration, country: Country) -> SKUData? {
        let loader = SKUDataLoader()
        switch search.family {
        case .iphone:
            return loader.phoneSKUData(forToken: search.token, country: country)
        case .watch:
            return loader.watchSKUData(forToken: search.token, country: country)
        case .mac:
            return loader.macSKUData(forToken: search.token, country: country)
        case .ipad:
            return loader.ipadSKUData(forToken: search.token, country: country)
        case .airpods:
            return loader.airpodsSKUData(forToken: search.token, country: country)
        case .homepod:
            return loader.homepodSKUData(forToken: search.token, country: country)
        case .avp:
            return loader.avpSKUData(forToken: search.token, country: country)
        }
    }
    
    private func productURL(for search: SearchConfiguration, partNumber: String, country: Country) -> URL? {
        let loader = SKUDataLoader()
        switch search.family {
        case .iphone:
            return loader.phoneProductURL(for: partNumber, country: country)
        case .watch:
            return loader.watchProductURL(for: partNumber, country: country)
        default:
            return nil
        }
    }
    
    private func categoryURL(for search: SearchConfiguration, country: Country) -> URL? {
        let loader = SKUDataLoader()
        let lc = country.shortcode.lowercased()
        switch search.family {
        case .iphone:
            return loader.phonePDPBaseURL(for: country, sourcePage: search.token)
        case .watch:
            return loader.watchCategoryURL(for: country, sourcePage: search.token)
        case .mac:
            return JSONCatalogMac.pdpBaseURL(for: country, sourcePage: search.token)
        case .ipad:
            return JSONCatalogiPad.pdpBaseURL(for: country, sourcePage: search.token)
        case .airpods:
            return JSONCatalogAirPods.pdpBaseURL(for: country, sourcePage: search.token)
        case .homepod:
            return JSONCatalogHomePod.pdpBaseURL(for: country, sourcePage: search.token)
        case .avp:
            return JSONCatalogAVP.pdpBaseURL(for: country, sourcePage: search.token) ?? URL(string: "https://www.apple.com/\(lc)/shop/buy-vision")
        }
    }
}
