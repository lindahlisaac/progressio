//
//  progressioApp.swift
//  progressio
//
//  Created by Isaac Lindahl on 12/29/25.
//

import SwiftUI
import HealthKit

@main
struct progressioApp: App {
    init() {
        MigrationRunner.shared.runIfNeeded()
        // Older builds enabled HK background delivery; turn it off so HealthKit
        // does not keep waking / buffering while the app sits idle.
        if HKHealthStore.isHealthDataAvailable() {
            HealthKitManager.shared.disableBackgroundDeliveryIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
