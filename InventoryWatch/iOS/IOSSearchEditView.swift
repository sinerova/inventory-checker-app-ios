//
//  IOSSearchEditView.swift
//  InventoryWatch
//

import SwiftUI

struct IOSSearchEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ViewModel
    
    let existingSearch: SearchConfiguration?
    let onSave: (SearchConfiguration) -> Void
    
    @State private var selectedCountryCode: String = "US"
    @State private var selectedFamily: ProductFamily = .iphone
    @State private var selectedToken: String = ""
    @State private var selectedStoreNumber: String = ""
    
    @State private var availableTokens: [String] = []
    @State private var tokenDisplayNames: [String: String] = [:]
    @State private var availableStores: [RetailStore] = []
    @State private var storeSearchText: String = ""
    @State private var isLoadingStores: Bool = false
    @State private var isShowingStorePicker: Bool = false
    
    // For marking individual SKUs as preferred
    @State private var availableSKUs: [(sku: String, name: String)] = []
    @AppStorage("preferredSKUs") private var preferredSKUsCSV: String = ""
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    
    private var currentCountry: Country {
        Countries[selectedCountryCode] ?? USData
    }
    
    private var preferredSKUsSet: Set<String> {
        Set(preferredSKUsCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
    
    private var selectedStore: RetailStore? {
        availableStores.first { $0.storeNumber == selectedStoreNumber }
    }
    
    init(existingSearch: SearchConfiguration? = nil, onSave: @escaping (SearchConfiguration) -> Void) {
        self.existingSearch = existingSearch
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Region & Product")) {
                    Picker("Country", selection: $selectedCountryCode) {
                        ForEach(AllCountries, id: \.shortcode) { country in
                            Text(country.name).tag(country.shortcode)
                        }
                    }
                    .onChange(of: selectedCountryCode) { _, _ in
                        selectedStoreNumber = ""
                        handleCountryOrFamilyChange()
                    }
                    
                    Picker("Family", selection: $selectedFamily) {
                        ForEach(ProductFamily.allCases) { family in
                            Text(family.displayName).tag(family)
                        }
                    }
                    .onChange(of: selectedFamily) { _, _ in
                        handleCountryOrFamilyChange()
                    }
                    
                    if availableTokens.isEmpty {
                        Text("No models found for this family in \(currentCountry.name).")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Model", selection: $selectedToken) {
                            ForEach(availableTokens, id: \.self) { token in
                                Text(tokenDisplayNames[token] ?? token).tag(token)
                            }
                        }
                        .onChange(of: selectedToken) { _, _ in
                            loadSKUsForSelectedToken()
                        }
                    }
                }
                
                Section(header: Text("Apple Store")) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let store = selectedStore {
                                Text(store.name)
                                    .font(.headline)
                                Text(store.address.cityStateDisplay)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else if selectedStoreNumber.isEmpty {
                                Text("No Store Selected")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Store #\(selectedStoreNumber)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("Choose") {
                            isShowingStorePicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                if !availableSKUs.isEmpty {
                    Section(header: Text("Favorite Models (\(availableSKUs.count) Variants)"),
                            footer: Text("Starred models receive priority in alerts and filtering.")) {
                        ForEach(availableSKUs, id: \.sku) { item in
                            let isFavorite = preferredSKUsSet.contains(item.sku)
                            Button {
                                toggleFavorite(item.sku)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(item.sku)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: isFavorite ? "star.fill" : "star")
                                        .foregroundColor(isFavorite ? .yellow : .secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(item.name), \(item.sku)")
                            .accessibilityValue(isFavorite ? "Favorite" : "Not favorite")
                            .accessibilityHint(isFavorite ? "Double tap to remove from favorites" : "Double tap to add to favorites")
                        }
                    }
                }
            }
            .navigationTitle(existingSearch == nil ? "New Search" : "Edit Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let id = existingSearch?.id ?? UUID()
                        let config = SearchConfiguration(
                            id: id,
                            family: selectedFamily,
                            token: selectedToken,
                            countryCode: selectedCountryCode,
                            storeNumber: selectedStoreNumber
                        )
                        onSave(config)
                        dismiss()
                    }
                    .disabled(selectedToken.isEmpty)
                }
            }
            .sheet(isPresented: $isShowingStorePicker) {
                storePickerSheet
                    .preferredColorScheme(appAppearance.colorScheme)
            }
            .preferredColorScheme(appAppearance.colorScheme)
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private var storePickerSheet: some View {
        NavigationStack {
            List {
                if isLoadingStores {
                    HStack {
                        Spacer()
                        ProgressView("Loading Apple Stores…")
                        Spacer()
                    }
                } else {
                    if storeSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            selectedStoreNumber = ""
                            isShowingStorePicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Any Store / No Preference")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Checks availability across available stores")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedStoreNumber.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Any Store / No Preference")
                        .accessibilityValue(selectedStoreNumber.isEmpty ? "Selected" : "")
                    }
                    
                    let filtered = filteredStores
                    if filtered.isEmpty && !storeSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                        ContentUnavailableView.search(text: storeSearchText)
                    } else {
                        ForEach(filtered, id: \.storeNumber) { store in
                            Button {
                                selectedStoreNumber = store.storeNumber
                                isShowingStorePicker = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(store.address.cityStateDisplay)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if store.storeNumber == selectedStoreNumber {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(store.name), \(store.address.cityStateDisplay)")
                            .accessibilityValue(store.storeNumber == selectedStoreNumber ? "Selected" : "")
                        }
                    }
                }
            }
            .searchable(text: $storeSearchText, prompt: "Search by store name, city, state, or store #")
            .navigationTitle("Select Apple Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isShowingStorePicker = false }
                }
            }
        }
    }
    
    private var filteredStores: [RetailStore] {
        if storeSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return availableStores
        }
        let query = storeSearchText.lowercased()
        return availableStores.filter { store in
            store.name.lowercased().contains(query) ||
            store.storeNumber.lowercased().contains(query) ||
            store.address.city.lowercased().contains(query) ||
            (store.address.stateName?.lowercased().contains(query) ?? false) ||
            (store.address.stateCode?.lowercased().contains(query) ?? false)
        }
    }
    
    private func setupInitialValues() {
        if let search = existingSearch {
            selectedCountryCode = search.countryCode
            selectedFamily = search.family
            selectedToken = search.token
            selectedStoreNumber = search.storeNumber
        } else {
            selectedCountryCode = model.defaultsVendor.preferredCountry.shortcode
            selectedFamily = .iphone
            selectedToken = ""
            selectedStoreNumber = model.defaultsVendor.preferredStoreNumber
        }
        handleCountryOrFamilyChange(preserveToken: true)
    }
    
    private func handleCountryOrFamilyChange(preserveToken: Bool = false) {
        loadTokens()
        if !preserveToken || !availableTokens.contains(selectedToken) {
            selectedToken = availableTokens.first ?? ""
        }
        loadStores()
        loadSKUsForSelectedToken()
    }
    
    private func loadTokens() {
        let country = currentCountry
        var tokens: [String] = []
        var names: [String: String] = [:]
        
        switch selectedFamily {
        case .iphone:
            tokens = JSONCatalogiPhone.categoriesSourcePages(for: country)
            for t in tokens {
                names[t] = JSONCatalogiPhone.tokenDisplayName(for: country, sourcePage: t) ?? selectedFamily.searchDisplayName(modelName: t)
            }
        case .watch:
            tokens = JSONCatalogAppleWatch.categoriesSourcePages(for: country)
            for t in tokens {
                names[t] = JSONCatalogAppleWatch.tokenDisplayName(for: country, sourcePage: t) ?? selectedFamily.searchDisplayName(modelName: t)
            }
        case .mac:
            tokens = JSONCatalogMac.categoriesSourcePages(for: country)
            for t in tokens {
                names[t] = JSONCatalogMac.tokenDisplayName(for: country, sourcePage: t) ?? selectedFamily.searchDisplayName(modelName: t)
            }
        case .ipad:
            tokens = JSONCatalogiPad.categoriesSourcePages(for: country)
            for t in tokens {
                names[t] = JSONCatalogiPad.tokenDisplayName(for: country, sourcePage: t) ?? selectedFamily.searchDisplayName(modelName: t)
            }
        case .airpods:
            tokens = JSONCatalogAirPods.categoriesSourcePages(for: country)
            for t in tokens {
                names[t] = JSONCatalogAirPods.tokenDisplayName(for: country, sourcePage: t) ?? selectedFamily.searchDisplayName(modelName: t)
            }
        case .homepod:
            tokens = JSONCatalogHomePod.categoriesSourcePages(for: country)
            for t in tokens {
                names[t] = JSONCatalogHomePod.tokenDisplayName(for: country, sourcePage: t) ?? selectedFamily.searchDisplayName(modelName: t)
            }
        case .avp:
            tokens = JSONCatalogAVP.categoriesSourcePages(for: country)
            for t in tokens {
                names[t] = JSONCatalogAVP.tokenDisplayName(for: country, sourcePage: t) ?? selectedFamily.searchDisplayName(modelName: t)
            }
        }
        
        self.availableTokens = tokens
        self.tokenDisplayNames = names
    }
    
    private func loadStores() {
        isLoadingStores = true
        let countryCode = selectedCountryCode
        Task {
            let stores = await model.stores(for: countryCode)
            await MainActor.run {
                if selectedCountryCode == countryCode {
                    self.availableStores = stores
                    self.isLoadingStores = false
                }
            }
        }
    }
    
    private func loadSKUsForSelectedToken() {
        guard !selectedToken.isEmpty else {
            availableSKUs = []
            return
        }
        let country = currentCountry
        let token = selectedToken
        let loader = SKUDataLoader()
        
        Task {
            let skuData: SKUData?
            switch selectedFamily {
            case .iphone:
                skuData = loader.phoneSKUData(forToken: token, country: country)
            case .watch:
                skuData = loader.watchSKUData(forToken: token, country: country)
            case .mac:
                skuData = loader.macSKUData(forToken: token, country: country)
            case .ipad:
                skuData = loader.ipadSKUData(forToken: token, country: country)
            case .airpods:
                skuData = loader.airpodsSKUData(forToken: token, country: country)
            case .homepod:
                skuData = loader.homepodSKUData(forToken: token, country: country)
            case .avp:
                skuData = loader.avpSKUData(forToken: token, country: country)
            }
            
            await MainActor.run {
                guard selectedToken == token else { return }
                if let data = skuData {
                    self.availableSKUs = data.orderedSKUs.map { sku in
                        (sku: sku, name: data.productName(forSKU: sku) ?? sku)
                    }
                } else {
                    self.availableSKUs = []
                }
            }
        }
    }
    
    private func toggleFavorite(_ sku: String) {
        var current = preferredSKUsSet
        if current.contains(sku) {
            current.remove(sku)
        } else {
            current.insert(sku)
        }
        preferredSKUsCSV = current.sorted().joined(separator: ",")
    }
}
