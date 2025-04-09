// BluetoothManager.swift

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var depthCharacteristic: CBCharacteristic?

    // Replace with the UUIDs you're using on the ESP32 side
    let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789abcdef0")
    let characteristicUUID = CBUUID(string: "abcdef12-3456-7890-abcd-ef1234567890")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Central Manager Delegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("🔍 Scanning for peripherals...")
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        } else {
            print("❌ Bluetooth not available")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        print("✅ Found peripheral: \(peripheral.name ?? "Unknown")")
        centralManager.stopScan()
        targetPeripheral = peripheral
        targetPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        print("🔗 Connected to \(peripheral.name ?? "ESP32")")
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                print("✅ Ready to write to characteristic")
                depthCharacteristic = characteristic
            }
        }
    }

    // MARK: - Write Grid

    func sendDepthGrid(_ grid: [[Float]]) {
        guard let peripheral = targetPeripheral,
              let characteristic = depthCharacteristic else {
            print("❌ Not connected or characteristic not ready")
            return
        }

        // Flatten the 3x3 grid
        let values = grid.flatMap { $0 }

        // Normalize to 0–255 (1 byte per cell)
        guard let max = values.max(), max > 0 else {
            print("⚠️ Invalid grid values")
            return
        }

        let byteArray: [UInt8] = values.map {
            let normalized = Swift.min(Swift.max($0 / max, 0), 1)  // clamp to 0–1
            return UInt8(clamping: Int(normalized * 255))
        }

        let data = Data(byteArray)
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        print("📤 Sent grid: \(byteArray)")
    }
}
