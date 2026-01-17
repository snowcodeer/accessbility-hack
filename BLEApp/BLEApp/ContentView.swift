//
//  ContentView.swift
//  BLEApp
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @State private var showARView = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Bar
                StatusBar(
                    message: bluetoothManager.statusMessage,
                    connectedDevice: bluetoothManager.connectedDevice
                )

                // Action Buttons
                ActionButtons(
                    bluetoothManager: bluetoothManager,
                    showARView: $showARView
                )

                // Device List
                DeviceList(bluetoothManager: bluetoothManager)
            }
            .navigationTitle("BLE Scanner")
            .sheet(isPresented: $showARView) {
                ARViewContainer()
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

// MARK: - Action Buttons
struct ActionButtons: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var showARView: Bool

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

                Button(action: {
                    showARView = true
                }) {
                    HStack {
                        Image(systemName: "arkit")
                        Text("Open AR")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
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
        .listStyle(InsetGroupedListStyle())
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

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
