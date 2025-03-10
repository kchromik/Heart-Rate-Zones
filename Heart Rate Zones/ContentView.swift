//
//  ContentView.swift
//  Heart Rate Zones
//
//  Created by Kevin Chromik on 06.03.25.
//

import SwiftUI
import Combine
import CoreBluetooth

// Main content view showing the heart rate with minimalist design
struct ContentView: View {
    // External providers injected via dependency injection
    @ObservedObject var heartRateProvider: HeartRateProvider
    @ObservedObject var bluetoothProvider: BluetoothDeviceProvider
    @Binding var hasCompletedInitialSetup: Bool
    
    // Local UI states
    @State private var showOnboarding = false
    @State private var showZoneEditor = false
    @State private var showBluetoothDevices = false
    @State private var animateHeartbeat = false
    
    init(heartRateProvider: HeartRateProvider, bluetoothProvider: BluetoothDeviceProvider, hasCompletedInitialSetup: Binding<Bool>) {
        self.heartRateProvider = heartRateProvider
        self.bluetoothProvider = bluetoothProvider
        self._hasCompletedInitialSetup = hasCompletedInitialSetup
    }
    
    var body: some View {
        ZStack {
            // Use the current zone color as the background for the entire screen
            heartRateProvider.currentZone.color
                .opacity(0.85)
                .ignoresSafeArea()
            
            // Subtle gradient overlay to add depth
            LinearGradient(
                gradient: Gradient(colors: [
                    .black.opacity(0.05),
                    .black.opacity(0.3)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Main content with minimalist design
            VStack {
                Spacer()
                
                // Zone name display
                Text(heartRateProvider.currentZone.name)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(30)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .animation(.spring(response: 0.4), value: heartRateProvider.currentZone.id)
                
                Spacer()
                
                // Heart rate display with minimalist design
                ZStack {
                    // Pulse animation circle
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 260, height: 260)
                        .scaleEffect(animateHeartbeat ? 1.08 : 1.0)
                        .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateHeartbeat)
                    
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 200, height: 200)
                    
                    // Heart rate display
                    VStack(spacing: 5) {
                        // Heart icon
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .scaleEffect(animateHeartbeat ? 1.1 : 1.0)
                            .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateHeartbeat)
                        
                        // Heart rate value
                        Text("\(heartRateProvider.currentRate)")
                            .font(.system(size: 76, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        
                        Text("BPM")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Bluetooth indicator if connected
                        if heartRateProvider.isUsingBluetoothData {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.heart.fill")
                                Text("Live")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(20)
                            .padding(.top, 8)
                        }
                    }
                }
                .onAppear {
                    animateHeartbeat = true
                }
                
                Spacer()
                
                // Minimalist button controls
                HStack(spacing: 20) {
                    // Connect device button with glassmorphism design
                    Button(action: {
                        showBluetoothDevices = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: heartRateProvider.isUsingBluetoothData ? "bluetooth" : "bluetooth")
                            Text(heartRateProvider.isUsingBluetoothData ? "Device" : "Connect")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 44)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(22)
                    }
                    
                    // Edit zones button with glassmorphism design
                    Button(action: {
                        showZoneEditor = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Zones")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 44)
                        .padding(.horizontal, 20)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(22)
                    }
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Onboarding sheet (shown on first launch)
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding, heartRateProvider: heartRateProvider)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showZoneEditor) {
            OnboardingView(
                showOnboarding: $showZoneEditor, 
                heartRateProvider: heartRateProvider,
                isEditMode: true
            )
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBluetoothDevices) {
            BluetoothDeviceView(
                bluetoothProvider: bluetoothProvider,
                heartRateProvider: heartRateProvider
            )
            .preferredColorScheme(.dark)
            .onDisappear {
                // Disconnect and return to home screen if needed
                if !bluetoothProvider.isConnected {
                    hasCompletedInitialSetup = false
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Preview provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            heartRateProvider: HeartRateProvider(),
            bluetoothProvider: BluetoothDeviceProvider(),
            hasCompletedInitialSetup: .constant(true)
        )
    }
}
