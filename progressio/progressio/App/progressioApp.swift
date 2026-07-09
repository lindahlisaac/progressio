//
//  progressioApp.swift
//  progressio
//
//  Created by Isaac Lindahl on 12/29/25.
//

import SwiftUI

@main
struct progressioApp: App {
    init() {
        MigrationRunner.shared.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
