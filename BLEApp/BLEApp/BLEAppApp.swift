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
    @StateObject private var bluetoothManager = BluetoothManager()

    var body: some View {
        TabView {
            ContentView(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("BLE Control", systemImage: "antenna.radiowaves.left.and.right")
                }

            ScannerView()
                .tabItem {
                    Label("AR Scan", systemImage: "viewfinder")
                }

            LocalizerView(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("AR Locate", systemImage: "location.fill")
                }
        }
    }
}
