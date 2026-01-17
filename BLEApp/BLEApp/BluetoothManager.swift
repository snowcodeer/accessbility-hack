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

    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var discoveredDeviceIds = Set<UUID>()

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
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let device = connectedDevice else { return }
        centralManager.cancelPeripheralConnection(device)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state

        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth Ready"
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
    }
}
