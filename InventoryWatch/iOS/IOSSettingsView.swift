//
//  IOSSettingsView.swift
//  InventoryWatch
//

import SwiftUI
import UserNotifications

struct IOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var model: ViewModel
    
    @AppStorage("preferredUpdateInterval") private var preferredUpdateInterval: Int = 1
    @AppStorage("notifyOnlyForPreferredModels") private var notifyOnlyForPreferredModels: Bool = false
    @AppStorage("showResultsOnlyForPreferredModels") private var showResultsOnlyForPreferredModels: Bool = false
    @AppStorage("shouldIncludeNearbyStores") private var shouldIncludeNearbyStores: Bool = true
    @AppStorage("useLargeText") private var useLargeText: Bool = false
    @AppStorage("customSku") private var customSku: String = ""
    @AppStorage("customSkuNickname") private var customSkuNickname: String = ""
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    
    @State private var editingSearch: SearchConfiguration?
    @State private var isAddingSearch: Bool = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Saved Searches
                Section(
                    header: Text("Saved Searches"),
                    footer: Text("Each search checks availability for a specific product and Apple Store.")
                ) {
                    if model.searchConfigurations.isEmpty {
                        Text("No searches configured yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(model.searchConfigurations) { search in
                            Button {
                                editingSearch = search
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(searchTitle(for: search))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(searchSubtitle(for: search))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(searchTitle(for: search)), \(searchSubtitle(for: search))")
                            .accessibilityHint("Double tap to edit this search")
                        }
                        .onDelete(perform: deleteSearches)
                        .onMove(perform: moveSearches)
                    }
                    
                    Button {
                        isAddingSearch = true
                    } label: {
                        Label("Add New Search", systemImage: "plus.circle.fill")
                    }
                }
                
                // MARK: - Refresh & Updates
                Section(
                    header: Text("Refresh & Updates"),
                    footer: Text("Note on iOS: Continuous 1-minute background polling is not permitted by iOS system policy. While the app is in the background, updates are scheduled using iOS Background Refresh, which runs at system-managed intervals depending on battery, device activity, and power. Foreground and manual refresh are always reliable.")
                ) {
                    Picker("Refresh Interval", selection: $preferredUpdateInterval) {
                        Text("Never").tag(0)
                        Text("1 minute (Foreground)").tag(1)
                        Text("5 minutes").tag(5)
                        Text("30 minutes").tag(30)
                        Text("60 minutes").tag(60)
                    }
                    .onChange(of: preferredUpdateInterval) { _, _ in
                        BackgroundRefreshManager.shared.scheduleAppRefresh()
                    }
                }
                
                // MARK: - Notifications
                Section(header: Text("Notifications")) {
                    HStack {
                        Text("Notification Status")
                        Spacer()
                        Text(statusDescription(notificationStatus))
                            .foregroundColor(.secondary)
                    }
                    
                    if notificationStatus == .denied {
                        Button("Open Settings to Enable") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    } else if notificationStatus != .authorized {
                        Button("Request Notification Permissions") {
                            requestNotifications()
                        }
                    }
                    
                    Toggle("Notify Only for Preferred Models", isOn: $notifyOnlyForPreferredModels)
                }
                
                // MARK: - Appearance
                Section(
                    header: Text("Appearance"),
                    footer: Text("Choose whether InventoryWatch matches your device appearance or stays in Light or Dark mode.")
                ) {
                    Picker("Appearance", selection: $appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.displayName).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // MARK: - Results Filtering & Display
                Section(header: Text("Display & Store Filters")) {
                    Toggle("Only Show Preferred Models in List", isOn: $showResultsOnlyForPreferredModels)
                        .onChange(of: showResultsOnlyForPreferredModels) { _, _ in
                            Task { await model.fetchLatestInventory() }
                        }
                    
                    Toggle("Include Nearby Stores", isOn: $shouldIncludeNearbyStores)
                        .onChange(of: shouldIncludeNearbyStores) { _, _ in
                            Task { await model.fetchLatestInventory() }
                        }
                    
                    Toggle("Use Larger Text", isOn: $useLargeText)
                }
                
                // MARK: - Custom SKU
                Section(
                    header: Text("Custom SKU Support"),
                    footer: Text("Optionally enter a specific Apple part number (e.g. MK1E4LL/A) to monitor alongside catalog items.")
                ) {
                    TextField("Custom SKU (e.g., MK1E4LL/A)", text: $customSku)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                    TextField("Nickname (optional)", text: $customSkuNickname)
                }
                
                // MARK: - About
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundColor(.secondary)
                    }
                    Text("InventoryWatch checks in-store pickup availability at Apple Retail Stores worldwide.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !model.searchConfigurations.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isAddingSearch) {
                IOSSearchEditView { newConfig in
                    model.addSearchConfiguration(newConfig)
                }
                .preferredColorScheme(appAppearance.colorScheme)
            }
            .sheet(item: $editingSearch) { search in
                IOSSearchEditView(existingSearch: search) { updatedConfig in
                    model.updateSearchConfiguration(updatedConfig)
                }
                .preferredColorScheme(appAppearance.colorScheme)
            }
            .preferredColorScheme(appAppearance.colorScheme)
            .onAppear {
                checkNotificationStatus()
            }
        }
    }
    
    private func deleteSearches(at offsets: IndexSet) {
        model.removeSearchConfigurations(at: offsets)
    }

    private func moveSearches(from source: IndexSet, to destination: Int) {
        model.moveSearchConfigurations(from: source, to: destination)
    }
    
    private func searchTitle(for search: SearchConfiguration) -> String {
        let country = Countries[search.countryCode] ?? USData
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
        return "\(modelTitle)"
    }
    
    private func searchSubtitle(for search: SearchConfiguration) -> String {
        let country = Countries[search.countryCode] ?? USData
        let store = search.storeNumber.isEmpty ? "All Stores" : "Store #\(search.storeNumber)"
        return "\(country.name) • \(store)"
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                self.notificationStatus = status
            }
        }
    }
    
    private func requestNotifications() {
        NotificationManager.shared.requestNotificationPermissions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkNotificationStatus()
        }
    }
    
    private func statusDescription(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Enabled"
        case .denied: return "Disabled in iOS Settings"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
}
