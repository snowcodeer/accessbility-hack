//
//  ContentView.swift
//  BLEApp
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @ObservedObject private var bluetoothManager: BluetoothManager
    @State private var selectedView = 0

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar with title and segmented control
                VStack(spacing: 12) {
                    HStack {
                        Text(selectedView == 0 ? "BLE Scanner" : "Terminal")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                    }

                    Picker("View", selection: $selectedView) {
                        Text("Scanner").tag(0)
                        Text("Terminal").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.systemBackground))
                .zIndex(100)

                if selectedView == 0 {
                    ScannerTab(bluetoothManager: bluetoothManager)
                        .clipped()
                } else {
                    TerminalTab(bluetoothManager: bluetoothManager)
                        .clipped()
                }
            }
        }
    }
}

// MARK: - Scanner Tab
struct ScannerTab: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        GeometryReader { geometry in
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
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - Terminal Tab
struct TerminalTab: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
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
                Text("Connect to a device from the Scanner view to use the terminal")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
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
        ContentView(bluetoothManager: BluetoothManager())
    }
}
