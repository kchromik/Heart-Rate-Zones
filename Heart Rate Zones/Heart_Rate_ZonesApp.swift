//
//  Heart_Rate_ZonesApp.swift
//  Heart Rate Zones
//
//  Created by Kevin Chromik on 06.03.25.
//

import SwiftUI
import Combine
import CoreBluetooth

@main
struct Heart_Rate_ZonesApp: App {
    var body: some Scene {
        WindowGroup {
            // Set up the main content coordinator
            AppContentCoordinator()
        }
    }
}

// This view coordinates between the ContentView and BluetoothDeviceView
struct AppContentCoordinator: View {
    // Create our shared model objects at this level
    @StateObject private var heartRateProvider = HeartRateProvider()
    @StateObject private var bluetoothProvider = BluetoothDeviceProvider()
    
    // Track whether the user has completed initial setup
    @AppStorage("hasCompletedInitialSetup") private var hasCompletedInitialSetup = false
    
    var body: some View {
        // Show ContentView when connected and setup is complete, otherwise show BluetoothDeviceView
        if hasCompletedInitialSetup && bluetoothProvider.isConnected {
            ContentView(
                heartRateProvider: heartRateProvider,
                bluetoothProvider: bluetoothProvider,
                hasCompletedInitialSetup: $hasCompletedInitialSetup
            )
        } else {
            BluetoothDeviceView(
                bluetoothProvider: bluetoothProvider,
                heartRateProvider: heartRateProvider
            )
            .onAppear {
                // Start scanning for devices when this view appears
                if !bluetoothProvider.isConnected && !bluetoothProvider.isScanning {
                    bluetoothProvider.startScanning()
                }
            }
        }
    }
}
