//
//  HarborPantryApp.swift
//  HarborPantry
//

import SwiftUI

@main
struct HarborPantryApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(dependencies)
                .task { await dependencies.bootstrap() }
        }
    }
}
