//
//  BLEAppApp.swift
//  BLEApp
//
//  Created on 2026-01-17
//

import SwiftUI

@main
struct BLEAppApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .persistentSystemOverlays(.hidden)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("BLE Control", systemImage: "antenna.radiowaves.left.and.right")
                }

            ScannerView()
                .tabItem {
                    Label("AR Scan", systemImage: "viewfinder")
                }

            LocalizerView()
                .tabItem {
                    Label("AR Locate", systemImage: "location.fill")
                }
        }
    }
}
