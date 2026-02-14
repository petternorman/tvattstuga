//
//  ContentView.swift
//  Tvattstuga
//
//  Created by Petter Norman on 2026-02-12.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        TabView {
            StatusTabView()
                .tabItem {
                    Label("Status", systemImage: "clock.badge.checkmark")
                }

            GroupsTabView()
                .tabItem {
                    Label("Groups", systemImage: "rectangle.grid.1x2")
                }

            SettingsTabView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .environmentObject(model)
        .task {
            await model.bootstrapIfNeeded()
        }
        .sheet(isPresented: $model.isLoginSheetPresented) {
            LoginSheetView()
                .environmentObject(model)
                .interactiveDismissDisabled(model.signedInUsername == nil)
        }
    }
}
