//
//  ContentView.swift
//  BLEApp
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()

    var body: some View {
        TabView {
            ScannerTab(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("Scanner", systemImage: "antenna.radiowaves.left.and.right")
                }

            TerminalTab(bluetoothManager: bluetoothManager)
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }

            ARTab()
                .ignoresSafeArea(.all, edges: .all)
                .tabItem {
                    Label("AR View", systemImage: "arkit")
                }

            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .ignoresSafeArea(.all, edges: .all)
    }
}

// MARK: - Scanner Tab
struct ScannerTab: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Status Bar
                    StatusBar(
                        message: bluetoothManager.statusMessage,
                        connectedDevice: bluetoothManager.connectedDevice
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    // Scan Control Button
                    ScanButton(bluetoothManager: bluetoothManager)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section(header: Text("Devices")) {
                    if bluetoothManager.discoveredDevices.isEmpty {
                        Text(bluetoothManager.isScanning ? "Scanning for devices..." : "No devices found")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                            DeviceRow(device: device)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    bluetoothManager.connect(to: device)
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .modifier(ScrollClipModifier())
            .navigationTitle("BLE Scanner")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Terminal Tab
struct TerminalTab: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        NavigationStack {
            if bluetoothManager.connectedDevice != nil {
                SerialTerminalView(bluetoothManager: bluetoothManager)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "terminal")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Device Connected")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Connect to a device from the Scanner tab to use the terminal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .navigationTitle("Terminal")
            }
        }
    }
}

// MARK: - AR Tab
struct ARTab: View {
    var body: some View {
        ARViewContainer()
    }
}

// MARK: - Settings Tab
struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("App")
                        Spacer()
                        Text("BLE Scanner")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Bluetooth")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Powered On")
                            .foregroundColor(.green)
                    }
                }
            }
            .modifier(ScrollClipModifier())
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Status Bar
struct StatusBar: View {
    let message: String
    let connectedDevice: CBPeripheral?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(connectedDevice != nil ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let device = connectedDevice {
                Text("Connected: \(device.name ?? device.identifier.uuidString)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Scan Button
struct ScanButton: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        HStack(spacing: 12) {
            if bluetoothManager.connectedDevice == nil {
                Button(action: {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
                    }
                }) {
                    HStack {
                        Image(systemName: bluetoothManager.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right")
                        Text(bluetoothManager.isScanning ? "Stop Scan" : "Start Scan")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bluetoothManager.isScanning ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(bluetoothManager.bluetoothState != .poweredOn)
            } else {
                Button(action: {
                    bluetoothManager.disconnect()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Disconnect")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Device List
struct DeviceList: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        List {
            if bluetoothManager.discoveredDevices.isEmpty {
                Text(bluetoothManager.isScanning ? "Scanning for devices..." : "No devices found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                    DeviceRow(device: device)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            bluetoothManager.connect(to: device)
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Device Row
struct DeviceRow: View {
    let device: CBPeripheral

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(device.name ?? "Unknown Device")
                .font(.headline)
            Text(device.identifier.uuidString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Scroll Clip Modifier
struct ScrollClipModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollClipDisabled()
        } else {
            content
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
