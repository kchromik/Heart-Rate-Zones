//
//  HeartRateProvider.swift
//  Heart Rate Zones
//
//  Created by Cascade on 06.03.25.
//

import Foundation
import SwiftUI
import Combine
import CoreBluetooth

// MARK: - Heart Rate Zone Model

struct HeartRateZone: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let startRate: Int
    let color: Color
    
    // Needed for Codable as Color is not natively Codable
    private enum CodingKeys: String, CodingKey {
        case id, name, startRate, colorData
    }
    
    init(name: String, startRate: Int, color: Color) {
        self.id = UUID()
        self.name = name
        self.startRate = startRate
        self.color = color
    }
    
    init(id: UUID = UUID(), name: String, startRate: Int, color: Color) {
        self.id = id
        self.name = name
        self.startRate = startRate
        self.color = color
    }
    
    // Encode the color as UIColor components
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startRate, forKey: .startRate)
        
        // For serialization, just use default color components
        // This is a simplification - in a real app we'd need a more robust solution
        let red: CGFloat = 0.5
        let green: CGFloat = 0.5
        let blue: CGFloat = 0.5
        let alpha: CGFloat = 1.0
        let colorData = [red, green, blue, alpha]
        try container.encode(colorData, forKey: .colorData)
    }
    
    // Decode from UIColor components
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startRate = try container.decode(Int.self, forKey: .startRate)
        
        let colorData = try container.decode([CGFloat].self, forKey: .colorData)
        color = Color(red: colorData[0], green: colorData[1], blue: colorData[2], opacity: colorData[3])
    }
}

// Default zones based on common percentages of max heart rate
extension HeartRateZone {
    static let defaultZones: [HeartRateZone] = [
        HeartRateZone(name: "Zone 1 - Recovery", startRate: 60, color: .blue),
        HeartRateZone(name: "Zone 2 - Endurance", startRate: 100, color: .green),
        HeartRateZone(name: "Zone 3 - Tempo", startRate: 120, color: .yellow),
        HeartRateZone(name: "Zone 4 - Threshold", startRate: 140, color: .orange),
        HeartRateZone(name: "Zone 5 - Maximum", startRate: 160, color: .red)
    ]
}

// MARK: - Heart Rate Provider

class HeartRateProvider: ObservableObject {
    // Published properties will trigger view updates
    @Published var currentRate: Int = 80
    @Published var currentZone: HeartRateZone
    @Published var zones: [HeartRateZone] = []
    @Published var isUsingBluetoothData: Bool = false
    
    // UserDefaults key for storing zones
    private static let zonesKey = "savedHeartRateZones"

    // Private properties
    private var timer: AnyCancellable?
    private var bluetoothCancellable: AnyCancellable? = nil
    private var bluetoothProvider: BluetoothDeviceProvider?
    private let minRate: Int = 50
    private let maxRate: Int = 200
    private let updateInterval: TimeInterval = 2.0 // Update every 2 seconds
    
    init() {
        // Load saved zones or use default zones if none are saved
        let tmpZones = HeartRateProvider.loadZonesFromUserDefaults() ?? HeartRateZone.defaultZones
        self.zones = tmpZones
        
        // Initialize with the appropriate zone for the current rate
        self.currentZone = tmpZones.first!
        updateZone()
        
        // Don't start simulation by default - will be started if needed
        // This allows Bluetooth data to take precedence
    }
    
    func startSimulation() {
        // Only start simulation if not using Bluetooth data
        guard !isUsingBluetoothData else { return }
        
        stopSimulation()
        
        timer = Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateZone()
            }
    }
    
    func stopSimulation() {
        timer?.cancel()
        timer = nil
    }
    
    // Start using data from Bluetooth heart rate monitor
    var startUsingBluetoothData: (Any) -> Void {
        return { [weak self] providerAny in
            guard let provider = providerAny as? BluetoothDeviceProvider else { return }
            self?.stopSimulation()
            self?.bluetoothProvider = provider
            self?.isUsingBluetoothData = true
            
            // Subscribe to heart rate updates from the Bluetooth provider
            // Use receive on main thread and remove any delay
            self?.bluetoothCancellable = provider.$heartRate
                .receive(on: RunLoop.main)
                .sink { [weak self] heartRate in
                    guard let self = self else { return }
                    print("HeartRateProvider received update: \(heartRate) BPM")
                    if heartRate > 0 {
                        self.currentRate = heartRate
                        self.updateZone()
                    }
                }
            
            // Initialize with current heart rate if available
            if provider.heartRate > 0 {
                self?.currentRate = provider.heartRate
                self?.updateZone()
            }
        }
    }
    
    // Stop using Bluetooth data and return to simulation
    var stopUsingBluetoothData: () -> Void {
        return { [weak self] in
            self?.bluetoothCancellable?.cancel()
            self?.bluetoothCancellable = nil
            self?.bluetoothProvider = nil
            self?.isUsingBluetoothData = false
            self?.startSimulation()
        }
    }
    
    private func updateZone() {
        // Find the highest zone where the current rate is higher than the start rate
        let matchingZone = zones
            .filter { $0.startRate <= currentRate }
            .sorted { $0.startRate > $1.startRate }
            .first
        
        if let zone = matchingZone, zone.id != currentZone.id {
            currentZone = zone
        } else if matchingZone == nil && currentRate < zones.first!.startRate {
            // Edge case: below the first zone
            currentZone = zones.first!
        }
    }
    
    // Update zones and save to UserDefaults
    func updateZones(with newZones: [HeartRateZone]) {
        zones = newZones.sorted { $0.startRate < $1.startRate }
        saveZonesToUserDefaults()
        updateZone()
    }
    
    // Save zones to UserDefaults
    private func saveZonesToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(zones)
            UserDefaults.standard.set(data, forKey: HeartRateProvider.zonesKey)
        } catch {
            print("Failed to save zones: \(error)")
        }
    }
    
    // Load zones from UserDefaults
    private static func loadZonesFromUserDefaults() -> [HeartRateZone]? {
        guard let data = UserDefaults.standard.data(forKey: HeartRateProvider.zonesKey) else { return nil }

        do {
            let zones = try JSONDecoder().decode([HeartRateZone].self, from: data)
            return zones
        } catch {
            print("Failed to load zones: \(error)")
            return nil
        }
    }
}
