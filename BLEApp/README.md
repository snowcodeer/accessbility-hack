# BLEApp - Swift + SwiftUI + ARKit + CoreBluetooth

A native iOS app combining Bluetooth Low Energy (BLE) and Augmented Reality (ARKit).

## Features

- **CoreBluetooth**: Scan, connect, and interact with BLE devices
- **ARKit + RealityKit**: World tracking, plane detection, and 3D object placement
- **SwiftUI**: Modern, declarative UI
- **Pure Swift**: Zero dependencies, zero deprecation warnings

## Quick Start

1. Open `BLEApp.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Connect a physical iOS device (ARKit requires real device)
4. Build and run (⌘R)

## Requirements

- Xcode 15.0+
- iOS 15.0+
- Physical iPhone (ARKit doesn't work on simulator)
- Bluetooth Low Energy device for testing

## Project Structure

```
BLEApp/
├── BLEAppApp.swift          # App entry point
├── ContentView.swift         # Main BLE scanner UI
├── BluetoothManager.swift    # CoreBluetooth manager
├── ARViewContainer.swift     # ARKit + RealityKit view
├── Info.plist               # Permissions
└── Assets.xcassets          # App assets
```

## How to Use

### BLE Scanning
1. Tap "Start Scan" to discover nearby BLE devices
2. Devices with names will appear in the list
3. Tap a device to connect
4. Once connected, services and characteristics are discovered

### AR View
1. Connect to a BLE device first
2. Tap "Open AR" button
3. Move your device to detect surfaces
4. Tap on detected surfaces to place 3D objects

## Permissions

The app requires these permissions (configured in Info.plist):

- **Bluetooth**: To scan and connect to BLE devices
- **Camera**: For AR features
- **ARKit**: Required device capability

## Compatible Devices

Works with any BLE device including:
- Nordic nRF52/nRF53/nRF54 development kits
- Fitness trackers
- Smart watches
- BLE beacons
- Custom BLE peripherals

## Next Steps

### Add BLE Data Reading
```swift
// In BluetoothManager.swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value else { return }
    // Parse your data here
}
```

### Visualize BLE Data in AR
```swift
// In ARViewContainer.swift - Coordinator
// Create 3D objects based on BLE sensor data
let sphere = ModelEntity(mesh: .generateSphere(radius: sensorValue))
```

## Why Pure Swift?

✅ Zero deprecation warnings
✅ Native performance
✅ Direct API access
✅ Perfect for ARKit
✅ Small app size
✅ Easy debugging

No React Native overhead, no JavaScript bridge, no legacy architecture issues.

## License

MIT License - Free to use and modify
