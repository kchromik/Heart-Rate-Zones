//
//  BluetoothDeviceProvider.swift
//  Heart Rate Zones
//
//  Created by Cascade on 06.03.25.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothDevice: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    
    init(peripheral: CBPeripheral) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Unknown Device"
    }
    
    static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

class BluetoothDeviceProvider: NSObject, ObservableObject {
    // Heart Rate Service UUID
    private let heartRateServiceUUID = CBUUID(string: "180D")
    // Heart Rate Measurement Characteristic UUID
    private let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")
    
    // Published properties for UI updates
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var selectedDevice: BluetoothDevice?
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false
    @Published var heartRate: Int = 0
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isAutoConnecting: Bool = false
    
    // Key for storing the last connected device ID
    private let lastConnectedDeviceKey = "lastConnectedHeartRateDeviceId"
    
    // Connection state enum
    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case scanning = "Scanning..."
        case connecting = "Connecting..."
        case connected = "Connected"
        case failed = "Connection Failed"
    }
    
    // CoreBluetooth manager
    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?
    private var heartRateCharacteristic: CBCharacteristic?
    
    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        centralManager.delegate = self
    }
    
    // Start scanning for heart rate devices
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        
        discoveredDevices = []
        isScanning = true
        connectionState = .scanning
        
        // Look for devices advertising the Heart Rate Service
        centralManager.scanForPeripherals(
            withServices: [heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Automatically stop scanning after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScanning()
        }
    }
    
    // Stop scanning for devices
    func stopScanning() {
        guard isScanning else { return }
        
        centralManager.stopScan()
        isScanning = false
        
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }
    
    // Connect to a selected device
    func connectToDevice(_ device: BluetoothDevice) {
        stopScanning()
        selectedDevice = device
        heartRatePeripheral = device.peripheral
        
        // Save this device ID for future reconnections
        UserDefaults.standard.set(device.id.uuidString, forKey: lastConnectedDeviceKey)
        heartRatePeripheral?.delegate = self
        
        connectionState = .connecting
        centralManager.connect(device.peripheral, options: nil)
    }
    
    // Disconnect from the current device
    func disconnect() {
        if let peripheral = heartRatePeripheral, isConnected {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // Parse heart rate data from the characteristic value
    private func parseHeartRate(from data: Data) -> Int {
        let reportData = [UInt8](data)
        let firstByte = reportData[0]
        
        // Check the format flag bit (bit 0 of the first byte)
        let isFormat16Bit = ((firstByte & 0x01) == 0x01)
        
        // Extract and return the heart rate value
        if isFormat16Bit {
            // Heart rate value is in the 2nd and 3rd bytes (16-bit uint format)
            return Int(reportData[1]) + (Int(reportData[2]) << 8)
        } else {
            // Heart rate value is in the 2nd byte (8-bit uint format)
            return Int(reportData[1])
        }
    }
}

// MARK: - Auto-reconnection

extension BluetoothDeviceProvider {
    // Attempt to reconnect to the last connected device
    private func attemptReconnectToSavedDevice() {
        guard let deviceIdString = UserDefaults.standard.string(forKey: lastConnectedDeviceKey),
              UUID(uuidString: deviceIdString) != nil else {
            return // No previously connected device found or invalid UUID
        }
        
        print("Attempting to reconnect to previously paired device: \(deviceIdString)")
        
        // Set the flag to show we're attempting auto-connection
        isAutoConnecting = true
        
        // Start scanning to find the device
        startScanning()
        
        // Set a timeout for the auto-reconnection attempt
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, !self.isConnected else { return }
            
            // Check if we've discovered the device in our scan
            if let savedDevice = self.discoveredDevices.first(where: { $0.id.uuidString == deviceIdString }) {
                print("Found previously connected device, auto-connecting")
                self.connectToDevice(savedDevice)
            } else {
                print("Previously connected device not found nearby")
                self.stopScanning()
            }
            
            // Reset the auto-connecting flag regardless of outcome
            self.isAutoConnecting = false
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothDeviceProvider: CBCentralManagerDelegate {
    // Called when the central manager's state updates
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Bluetooth is on and ready
            print("Bluetooth is powered on and ready")
            // Attempt to reconnect to the last connected device when Bluetooth is ready
            if !isConnected && !isScanning {
                attemptReconnectToSavedDevice()
            }
        case .poweredOff:
            // Bluetooth is off
            print("Bluetooth is powered off")
            connectionState = .disconnected
            isConnected = false
            discoveredDevices = []
        case .unsupported:
            print("Bluetooth is not supported on this device")
        case .unauthorized:
            print("Bluetooth is not authorized")
        case .resetting:
            print("Bluetooth is resetting")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }
    
    // Called when a peripheral is discovered during scanning
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Only include devices with a name
        guard let peripheralName = peripheral.name, !peripheralName.isEmpty else { return }
        
        let device = BluetoothDevice(peripheral: peripheral)
        
        // Add to discovered devices if not already present
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
        }
    }
    
    // Called when a connection to a peripheral succeeds
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        isConnected = true
        connectionState = .connected
        isAutoConnecting = false  // Reset auto-connecting flag on successful connection
        
        // Discover the heart rate service
        peripheral.discoverServices([heartRateServiceUUID])
    }
    
    // Called when a connection to a peripheral fails
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
        connectionState = .failed
        isConnected = false
        isAutoConnecting = false  // Reset auto-connecting flag on connection failure
    }
    
    // Called when a peripheral is disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "No error")")
        connectionState = .disconnected
        isConnected = false
        isAutoConnecting = false  // Reset auto-connecting flag on disconnect
        heartRatePeripheral = nil
        heartRateCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothDeviceProvider: CBPeripheralDelegate {
    // Called when services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            connectionState = .failed
            return
        }
        
        guard let services = peripheral.services else { return }
        
        // Look for the heart rate service
        for service in services {
            if service.uuid == heartRateServiceUUID {
                print("Heart Rate service found")
                // Discover the heart rate measurement characteristic
                peripheral.discoverCharacteristics([heartRateMeasurementCharacteristicUUID], for: service)
            }
        }
    }
    
    // Called when characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            connectionState = .failed
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        // Look for the heart rate measurement characteristic
        for characteristic in characteristics {
            if characteristic.uuid == heartRateMeasurementCharacteristicUUID {
                print("Heart Rate Measurement characteristic found")
                
                // Save a reference to the characteristic
                heartRateCharacteristic = characteristic
                
                // Subscribe to notifications for this characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                
                // Update the connection state
                connectionState = .connected
                isConnected = true
            }
        }
    }
    
    // Called when characteristic value updates
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating characteristic value: \(error!.localizedDescription)")
            return
        }
        
        // Check if this is the heart rate measurement characteristic
        if characteristic.uuid == heartRateMeasurementCharacteristicUUID, let data = characteristic.value {
            // Parse and update the heart rate value
            let heartRateValue = parseHeartRate(from: data)
            
            // Log and immediately update the heart rate on the main thread
            print("Received heart rate: \(heartRateValue) BPM")
            
            // Using DispatchQueue.main.async to update UI properties
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Set the heartRate property which will trigger the publisher
                // that HeartRateProvider is observing
                if self.heartRate != heartRateValue {
                    self.heartRate = heartRateValue
                }
            }
        }
    }
    
    // Called when notification state changes
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error changing notification state: \(error!.localizedDescription)")
            return
        }
        
        if characteristic.uuid == heartRateMeasurementCharacteristicUUID {
            if characteristic.isNotifying {
                print("Notifications started for Heart Rate Measurement")
            } else {
                print("Notifications stopped for Heart Rate Measurement")
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }
}
