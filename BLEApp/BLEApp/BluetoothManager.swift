//
//  BluetoothManager.swift
//  BLEApp
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var isScanning = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var statusMessage = "Bluetooth Off"
    @Published var receivedMessages: [String] = []

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var discoveredDeviceIds = Set<UUID>()

    // Auto-connect configuration
    private let autoConnectDeviceName = "Smartibot a06c"
    private let autoConnectDeviceUUID = UUID(uuidString: "6D35A545-4747-B962-42A0-FEC9B6F26D88")
    @Published var autoConnectEnabled = true

    // Nordic UART Service UUIDs
    private let nordicUARTServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let nordicUARTTXCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Phone writes here
    private let nordicUARTRXCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // Phone receives here

    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            statusMessage = "Bluetooth is not ready"
            return
        }

        discoveredDevices.removeAll()
        discoveredDeviceIds.removeAll()
        isScanning = true
        statusMessage = "Scanning..."

        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])

        // Auto-stop after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.stopScanning()
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        statusMessage = discoveredDevices.isEmpty ? "No devices found" : "Found \(discoveredDevices.count) device(s)"
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        statusMessage = "Connecting..."
        // Retain peripheral immediately to avoid "unused peripheral" warning
        connectedDevice = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let device = connectedDevice else { return }
        centralManager.cancelPeripheralConnection(device)
    }

    // MARK: - Manual Read/Write Methods

    /// Read a characteristic value manually
    func readCharacteristic(serviceUUID: String, characteristicUUID: String) {
        guard let device = connectedDevice,
              let service = device.services?.first(where: { $0.uuid.uuidString == serviceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid.uuidString == characteristicUUID }) else {
            print("Characteristic not found")
            return
        }
        device.readValue(for: characteristic)
    }

    /// Write data to a characteristic
    func writeCharacteristic(serviceUUID: String, characteristicUUID: String, data: Data, withResponse: Bool = true) {
        guard let device = connectedDevice,
              let service = device.services?.first(where: { $0.uuid.uuidString == serviceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid.uuidString == characteristicUUID }) else {
            print("Characteristic not found")
            return
        }

        let writeType: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse
        device.writeValue(data, for: characteristic, type: writeType)
    }

    /// Subscribe/unsubscribe to characteristic notifications
    func setNotify(serviceUUID: String, characteristicUUID: String, enabled: Bool) {
        guard let device = connectedDevice,
              let service = device.services?.first(where: { $0.uuid.uuidString == serviceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid.uuidString == characteristicUUID }) else {
            print("Characteristic not found")
            return
        }
        device.setNotifyValue(enabled, for: characteristic)
    }

    // MARK: - Nordic UART Service Helper

    /// Send text to Nordic UART Service
    func sendText(_ text: String) {
        guard let device = connectedDevice,
              let service = device.services?.first(where: { $0.uuid == nordicUARTServiceUUID }),
              let txCharacteristic = service.characteristics?.first(where: { $0.uuid == nordicUARTTXCharacteristicUUID }),
              let data = text.data(using: .utf8) else {
            print("Cannot send text - UART service not found")
            return
        }

        device.writeValue(data, for: txCharacteristic, type: .withoutResponse)

        // Show what was actually sent in hex
        let hexBytes = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        print("Sent: \(text)")
        print("  Hex: \(hexBytes)")
        print("  Bytes: \(Array(data))")

        // Add to messages for display (strip control chars for display)
        let displayText = text.replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
        DispatchQueue.main.async {
            self.receivedMessages.append("→ \(displayText)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state

        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth Ready"
            // Auto-start scanning if auto-connect is enabled
            if autoConnectEnabled && connectedDevice == nil {
                startScanning()
            }
        case .poweredOff:
            statusMessage = "Bluetooth Off"
        case .unauthorized:
            statusMessage = "Bluetooth Unauthorized"
        case .unsupported:
            statusMessage = "Bluetooth Not Supported"
        default:
            statusMessage = "Bluetooth Unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Only add devices with names to avoid cluttering the list
        guard peripheral.name != nil else { return }

        // Avoid duplicates
        guard !discoveredDeviceIds.contains(peripheral.identifier) else { return }

        discoveredDeviceIds.insert(peripheral.identifier)
        discoveredDevices.append(peripheral)

        // Auto-connect if enabled and device matches
        if autoConnectEnabled && connectedDevice == nil {
            let matchesName = peripheral.name == autoConnectDeviceName
            let matchesUUID = peripheral.identifier == autoConnectDeviceUUID

            if matchesName || matchesUUID {
                print("Auto-connecting to \(peripheral.name ?? "device")...")
                connect(to: peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedDevice = peripheral
        statusMessage = "Connected to \(peripheral.name ?? "Device")"

        // Set delegate to discover services
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral == connectedDevice {
            connectedDevice = nil
            statusMessage = "Disconnected"
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        statusMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        print("Discovered \(services.count) services")

        // Discover characteristics for each service
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        print("Discovered \(characteristics.count) characteristics for service \(service.uuid)")

        // Example: Auto-subscribe to characteristics that support notifications
        for characteristic in characteristics {
            print("  Characteristic: \(characteristic.uuid)")
            print("  Properties: \(characteristic.properties)")

            // Subscribe to notifications if available
            if characteristic.properties.contains(.notify) {
                print("  → Subscribing to notifications")
                peripheral.setNotifyValue(true, for: characteristic)
            }

            // Auto-read if readable
            if characteristic.properties.contains(.read) {
                print("  → Reading value")
                peripheral.readValue(for: characteristic)
            }
        }
    }

    // Called when a characteristic value is read or updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            print("No data received for \(characteristic.uuid)")
            return
        }

        print("Received data from \(characteristic.uuid):")
        print("  Raw bytes: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")

        // Convert to string and add to messages
        if let string = String(data: data, encoding: .utf8) {
            print("  As string: \(string)")

            // Add to received messages for UI display
            DispatchQueue.main.async {
                self.receivedMessages.append(string)
                // Keep only last 100 messages
                if self.receivedMessages.count > 100 {
                    self.receivedMessages.removeFirst()
                }
            }
        }
    }

    // Called when write completes
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Write failed: \(error.localizedDescription)")
        } else {
            print("Successfully wrote to \(characteristic.uuid)")
        }
    }

    // Called when notification state changes
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Notification state change failed: \(error.localizedDescription)")
        } else {
            print("Notifications \(characteristic.isNotifying ? "enabled" : "disabled") for \(characteristic.uuid)")
        }
    }
}
