//
//  InventoryWatchiOSApp.swift
//  InventoryWatch
//

import SwiftUI

@main
struct InventoryWatchiOSApp: App {
    @StateObject private var model: ViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    
    init() {
        LegacyPreferencesMigration.migrateIfNeeded()
        let vm = ViewModel()
        _model = StateObject(wrappedValue: vm)
        BackgroundRefreshManager.shared.registerBackgroundTask(model: vm)
    }
    
    var body: some Scene {
        WindowGroup {
            IOSContentView()
                .environmentObject(model)
                .preferredColorScheme(appAppearance.colorScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefreshManager.shared.scheduleAppRefresh()
            } else if newPhase == .active {
                Task {
                    await model.fetchLatestInventory()
                }
            }
        }
    }
}
