# BLE + ARKit App (Pure Swift)

A native iOS app combining **CoreBluetooth** (BLE) and **ARKit** for connecting to Bluetooth devices and visualizing data in augmented reality.

## Features

✅ **CoreBluetooth BLE**
- Scan for nearby BLE devices
- Connect/disconnect to devices
- Discover services & characteristics
- Compatible with Nordic nRF5 devices (nRF52, nRF53, nRF54)

✅ **ARKit + RealityKit**
- World tracking with plane detection
- Tap to place 3D objects
- Person segmentation (iPhone 12+)
- Ready for BLE data visualization

✅ **SwiftUI Interface**
- Modern, clean UI
- Real-time device updates
- Connection status
- Modal AR view

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **BLE**: CoreBluetooth
- **AR**: ARKit + RealityKit
- **Min iOS**: 15.0
- **Device Required**: Physical iPhone (ARKit doesn't work on simulator)

## Quick Start

### Prerequisites

- macOS with Xcode 15.0+
- iOS device with iOS 15.0+ (ARKit requires physical device)
- Apple Developer account (for device testing)
- BLE device for testing (optional: Nordic nRF52 DK, fitness tracker, etc.)

### Setup Instructions

**See [SETUP.md](SETUP.md) for detailed step-by-step instructions.**

Quick version:

1. Open Xcode
2. Create new iOS App project named "BLEApp"
3. Select SwiftUI + Swift
4. Save to this directory (will merge with existing files)
5. Add all `.swift` files to the project
6. Replace Info.plist content
7. Build & Run on a real device

## Project Structure

```
BLEApp/
├── BLEAppApp.swift          # App entry point (@main)
├── ContentView.swift         # Main UI with BLE scanner
├── BluetoothManager.swift    # CoreBluetooth manager (ObservableObject)
├── ARViewContainer.swift     # ARKit view with RealityKit
├── Info.plist               # Permissions (Bluetooth, Camera, ARKit)
└── README.md                # This file
```

## How It Works

### BLE Flow

```
App Launch
  ↓
BluetoothManager initializes CBCentralManager
  ↓
User taps "Start Scan"
  ↓
Discovers BLE devices → Shows in list
  ↓
User taps device → Connects → Discovers services/characteristics
  ↓
Connected → Can read/write/subscribe to characteristics
```

### AR Flow

```
User connects to BLE device
  ↓
"Open AR" button appears
  ↓
Tap "Open AR" → ARViewContainer loads
  ↓
ARKit starts world tracking + plane detection
  ↓
User taps screen → Places 3D object on detected surface
```

## Usage

### Scanning for BLE Devices

1. Launch app
2. Grant Bluetooth permission
3. Tap **Start Scan**
4. Devices appear in the list (only devices with names are shown)
5. Tap a device to connect

### Connecting to nRF5 Devices

Your Nordic device should be:
- Powered on
- Advertising (running BLE firmware)
- Broadcasting a device name
- Within Bluetooth range (~10m)

### Using AR

1. Connect to any BLE device first
2. Tap **Open AR** button
3. Grant camera permission
4. Move device to detect surfaces
5. Tap on a surface to place a 3D sphere

## Integration Examples

### Read BLE Data

Add to `BluetoothManager.swift`:

```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value else { return }

    // Parse your nRF5 data
    let bytes = [UInt8](data)
    print("Received: \(bytes)")

    // Update @Published property to trigger UI update
}
```

### Visualize BLE Data in AR

Combine BLE + AR:

```swift
// 1. Read sensor data from nRF5 device
// 2. Parse values (temperature, accelerometer, etc.)
// 3. Update AR visualization

// Example: Place spheres based on sensor reading
let temperature = parsedData.temperature
let color = UIColor(hue: temperature / 100, saturation: 1, brightness: 1, alpha: 1)
let sphere = ModelEntity(mesh: .generateSphere(radius: 0.05),
                         materials: [SimpleMaterial(color: color, isMetallic: true)])
```

## Python Integration (Optional)

Since Python cannot run on iOS, use one of these architectures:

### Option 1: Backend API
```
iOS (BLE + ARKit) → HTTP/WebSocket → Python Server → Process data → Return results
```

### Option 2: Local Computer Bridge
```
iOS (BLE) → WebSocket → Mac/PC Python script → Process → Send back
```

### Option 3: CoreML
```
Python (Train model) → Export to CoreML → iOS app runs model locally
```

See the main project README for more details.

## Advantages Over React Native

✅ **Zero deprecation warnings** - Pure Swift, no legacy code
✅ **Better performance** - Native ARKit rendering at 60fps
✅ **Direct API access** - No JavaScript bridge overhead
✅ **Smaller app size** - No React Native bundle
✅ **Easier debugging** - Xcode instruments, breakpoints
✅ **Full ARKit features** - Immediate access to all iOS APIs
✅ **Better BLE stability** - Direct CoreBluetooth access

## Nordic nRF5 Compatibility

Works with any nRF5-based BLE device:

- **Development Kits**: nRF52 DK, nRF53 DK, nRF54 DK
- **Thingy**: Thingy:52, Thingy:53
- **Custom devices**: Any device running Nordic SDK firmware

Your nRF firmware should expose GATT services that this app can discover.

## Device Requirements

### iOS Device Must Have:
- iPhone 6s or later (for ARKit)
- iOS 15.0 or later
- Bluetooth Low Energy support
- Rear camera (for AR)

### Simulator Limitations:
- ❌ ARKit doesn't work
- ❌ CoreBluetooth limited functionality
- ✅ UI development only

**Always test on a real device.**

## Troubleshooting

### Bluetooth Issues

**"Bluetooth Unauthorized"**
- Settings > Privacy & Security > Bluetooth > Enable for BLEApp

**No devices found**
- Ensure Bluetooth is on
- Check device is advertising
- Move closer to BLE device
- Device must have a name to appear in list

### AR Issues

**"Camera Unauthorized"**
- Settings > Privacy & Security > Camera > Enable for BLEApp

**AR not working**
- ARKit requires physical device
- Needs iPhone 6s or later
- Ensure good lighting
- Move device to detect surfaces

### Build Issues

**Missing files**
- Ensure all `.swift` files are added to target
- Check File Inspector > Target Membership

**Info.plist errors**
- Verify all permission keys are present
- Check for syntax errors in XML

## Next Steps

### For Development:
1. Customize UI colors/layout in `ContentView.swift`
2. Add BLE read/write logic in `BluetoothManager.swift`
3. Create custom AR content in `ARViewContainer.swift`
4. Add data models for your nRF5 sensor data

### For Production:
1. Add error handling and edge cases
2. Implement BLE reconnection logic
3. Add data persistence (UserDefaults/CoreData)
4. Create custom 3D models for AR
5. Add analytics and crash reporting

### Integration Ideas:
- Visualize nRF5 sensor data as AR graphs
- Place AR markers at locations based on BLE RSSI
- Control nRF5 device LEDs from AR interface
- Record AR + BLE data sessions
- Share AR scenes with BLE device info

## Resources

- [Apple CoreBluetooth Documentation](https://developer.apple.com/documentation/corebluetooth)
- [Apple ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [Nordic nRF5 SDK](https://www.nordicsemi.com/Products/Development-software/nrf5-sdk)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)

## License

Open source - MIT License

---

Built with ❤️ using pure Swift
