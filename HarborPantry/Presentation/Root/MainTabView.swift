//
//  MainTabView.swift
//  HarborPantry
//
//  Presentation layer — the five-tab shell. Each tab owns its own navigation
//  stack (`NavigationView` in stack style, since iOS 15 has no
//  `NavigationStack`).
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Binding var showProfileSetup: Bool
    @State private var selectedTab: Tab = .home

    enum Tab: Hashable {
        case home, inventory, meals, shopping, more
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(dependencies: dependencies, onNavigate: handleQuickAction)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            InventoryView(dependencies: dependencies)
                .tabItem { Label("Inventory", systemImage: "shippingbox.fill") }
                .tag(Tab.inventory)

            MealPlanView(dependencies: dependencies)
                .tabItem { Label("Meals", systemImage: "fork.knife") }
                .tag(Tab.meals)

            ShoppingListView(dependencies: dependencies)
                .tabItem { Label("Shopping", systemImage: "cart.fill") }
                .tag(Tab.shopping)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(Tab.more)
        }
        .tint(HarborColor.accent)
        .sheet(isPresented: $showProfileSetup) {
            NavigationView {
                PantryProfileView(dependencies: dependencies, mode: .setup) {
                    showProfileSetup = false
                    selectedTab = .inventory
                }
            }
            .navigationViewStyle(.stack)
            .environmentObject(dependencies)
        }
    }

    /// Home's quick actions jump to the right tab.
    private func handleQuickAction(_ destination: HomeDestination) {
        switch destination {
        case .inventory, .addProduct, .useSoon:
            selectedTab = .inventory
        case .mealPlan:
            selectedTab = .meals
        case .shopping:
            selectedTab = .shopping
        case .prep:
            selectedTab = .more
        }
    }
}

/// Destinations Home can push the user towards.
enum HomeDestination: Hashable {
    case inventory
    case addProduct
    case useSoon
    case mealPlan
    case shopping
    case prep
}
