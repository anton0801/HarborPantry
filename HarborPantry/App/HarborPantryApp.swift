//
//  HarborPantryApp.swift
//  HarborPantry
//

import SwiftUI

@main
struct HarborPantryApp: App {
    @StateObject private var dependencies = AppDependencies()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environmentObject(dependencies)
                .task { await dependencies.bootstrap() }
        }
    }
}
