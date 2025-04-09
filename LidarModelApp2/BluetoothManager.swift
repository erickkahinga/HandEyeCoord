// BluetoothManager.swift

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var depthCharacteristic: CBCharacteristic?

    // Replace with the UUIDs you're using on the ESP32 side
    let serviceUUID = CBUUID(string:  "12345678-1234-1234-1234-123456789ABC")
    let characteristicUUID = CBUUID(string:  "0c857149-c4fb-43ba-b0dc-7ecf72de141e")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Central Manager Delegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("🔍 Scanning for peripherals...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)

        } else {
            print("❌ Bluetooth not available")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        let name = peripheral.name ?? "Unnamed"
        print("\n🔎 Discovered peripheral: \(name)")
        print("📡 RSSI: \(RSSI)")
        print("📦 Advertisement Data: \(advertisementData)")

        // ✅ Connect to the specific ESP32 by name
        if name == "HandEyeESP32" {
            print("✅ Connecting to: \(name)")
            centralManager.stopScan()
            targetPeripheral = peripheral
            targetPeripheral?.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
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

    var isReadyToSend = false

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                print("✅ Ready to write to characteristic")
                depthCharacteristic = characteristic
                isReadyToSend = true
            }
        }
    }


    // MARK: - Write Grid

    func sendDepthGrid(_ grid: [[Float]]) {
        
        guard isReadyToSend,
              let peripheral = targetPeripheral,
              let characteristic = depthCharacteristic else {
            print("❌ Not ready to send")
            return
        }
        

        // Flatten the 3x4 grid
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
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("📤 Sent grid: \(byteArray)")
    }
}
