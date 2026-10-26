//
//  BackgroundRefreshManager.swift
//  InventoryWatch
//

import Foundation
import BackgroundTasks
import UIKit

@MainActor
final class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    
    static let backgroundTaskIdentifier = "net.brendamour.InventoryWatch.refresh"
    
    private init() {}
    
    func registerBackgroundTask(model: ViewModel) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                await self.handleAppRefresh(task: appRefreshTask, model: model)
            }
        }
    }
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        // iOS requires background refresh intervals to be reasonable (typically >= 15 min).
        // If user set an interval > 0, schedule at least 15 min from now or interval minutes, whichever is larger.
        let defaults = DefaultsVendor()
        let intervalMinutes = defaults.preferredUpdateInterval
        guard intervalMinutes > 0 else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)
            return
        }
        
        let delaySeconds = max(Double(intervalMinutes * 60), 15 * 60)
        request.earliestBeginDate = Date(timeIntervalSinceNow: delaySeconds)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled background app refresh for ~\(delaySeconds / 60) minutes from now")
        } catch {
            print("⚠️ Could not schedule background app refresh: \(error.localizedDescription)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask, model: ViewModel) async {
        // Reschedule next background refresh immediately
        scheduleAppRefresh()
        
        let fetchTask = Task { @MainActor in
            await model.fetchLatestInventory()
        }
        
        // Handle expiration
        task.expirationHandler = {
            print("⏳ Background task expired before completion.")
            fetchTask.cancel()
            task.setTaskCompleted(success: false)
        }
        
        // Fetch inventory in background
        await fetchTask.value
        if let error = model.errorState {
            print("❌ Background refresh encountered error: \(error.localizedDescription)")
            task.setTaskCompleted(success: false)
        } else {
            print("✅ Background refresh completed successfully.")
            task.setTaskCompleted(success: true)
        }
    }
}
