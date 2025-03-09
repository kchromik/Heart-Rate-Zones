//
//  BluetoothDeviceView.swift
//  Heart Rate Zones
//
//  Created by Cascade on 06.03.25.
//

import SwiftUI

struct BluetoothDeviceView: View {

    @ObservedObject var bluetoothProvider: BluetoothDeviceProvider
    @ObservedObject var heartRateProvider: HeartRateProvider
    @Environment(\.presentationMode) var presentationMode
    
    // Optional binding for direct dismissal when used as a sheet
    private var isSheet: Bool = false
    
    @State private var selectedDevice: BluetoothDevice?
    @State private var showConfirmation = false
    @State private var showConnectionError = false
    @State private var showContinueButton = false
    
    // Animation state for auto-connect progress
    @State private var autoConnectProgress = 0.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color(#colorLiteral(red: 0.09019608051, green: 0.09019608051, blue: 0.09019608051, alpha: 1)), Color(#colorLiteral(red: 0.1764705926, green: 0.1764705926, blue: 0.1764705926, alpha: 1))]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack {
                    if bluetoothProvider.isConnected {
                        connectedView
                    } else {
                        deviceListView
                    }
                }
                .padding()
                
                // Auto-connecting overlay
                if bluetoothProvider.isAutoConnecting {
                    autoConnectingOverlay
                }
            }
            .navigationTitle("Heart Rate Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !bluetoothProvider.isConnected {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bluetoothProvider.isConnected {
                        Button(action: {
                            bluetoothProvider.disconnect()
                            
                        }) {
                            Text("Disconnect")
                                .foregroundColor(.red)
                        }
                    } else if !bluetoothProvider.isScanning {
                        Button(action: {
                            bluetoothProvider.startScanning()
                        }) {
                            Text("Scan")
                        }
                    }
                }
            }
            .alert(isPresented: $showConnectionError) {
                Alert(
                    title: Text("Connection Failed"),
                    message: Text("Unable to connect to the selected device. Please try again."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .alert(isPresented: $showConfirmation) {
            Alert(
                title: Text("Connect to Device"),
                message: Text("Do you want to connect to \(selectedDevice?.name ?? "this device")?\n\nMake sure the device is nearby and ready to pair."),
                primaryButton: .default(Text("Connect")) {
                    if let device = selectedDevice {
                        bluetoothProvider.connectToDevice(device)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: bluetoothProvider.connectionState) { state in
            if state == .failed {
                showConnectionError = true
            } else if state == .connected {
                heartRateProvider.startUsingBluetoothData(bluetoothProvider)
                // After successful connection, show the continue button if not in sheet mode
                if !isSheet {
                    showContinueButton = true
                }
            }
        }
        .onAppear {
            // Start scanning when view appears if not connected
            if !bluetoothProvider.isConnected && !bluetoothProvider.isScanning {
                bluetoothProvider.startScanning()
            }
            
            // Show continue button if already connected and not in sheet mode
            if bluetoothProvider.isConnected && !isSheet {
                showContinueButton = true
            }
        }
    }
    
    // Auto-connecting overlay
    private var autoConnectingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Reconnecting to Last Device")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Looking for your previously connected device...")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.9))
            )
            .shadow(radius: 10)
            .onAppear {
                // Start animation for progress indicator
                withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    autoConnectProgress = 1.0
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: bluetoothProvider.isAutoConnecting)
    }
    
    // View when connected to a device
    private var connectedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .padding()
            
            VStack(spacing: 10) {
                Text("Connected to")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text(bluetoothProvider.selectedDevice?.name ?? "Device")
                    .font(.title)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                
                if isSheet {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)
                }
            }
            
            VStack(spacing: 10) {
                Text("Heart Rate")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text("\(bluetoothProvider.heartRate)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("BPM")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
            
            Spacer()
            
            if !isSheet && showContinueButton {
                NavigationLink(destination: ContentView(
                    heartRateProvider: heartRateProvider,
                    bluetoothProvider: bluetoothProvider,
                    hasCompletedInitialSetup: .constant(true)
                )) {
                    Text("Continue to Dashboard")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    // View showing list of available devices
    private var deviceListView: some View {
        VStack {
            if bluetoothProvider.isScanning {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    
                    Text("Scanning for heart rate devices...")
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button(action: {
                        bluetoothProvider.stopScanning()
                    }) {
                        Text("Stop")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)
            }
            
            if bluetoothProvider.discoveredDevices.isEmpty {
                VStack(spacing: 20) {
                    if !bluetoothProvider.isScanning {
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No heart rate devices found")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Make sure your heart rate monitor is turned on and in pairing mode.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            bluetoothProvider.startScanning()
                        }) {
                            Text("Scan for Devices")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section(header: Text("Available Devices").foregroundColor(.gray)) {
                        ForEach(bluetoothProvider.discoveredDevices) { device in
                            Button(action: {
                                selectedDevice = device
                                showConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "heart.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                    
                                    Text(device.name)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        // Alert moved to the main view
    }
}

// Add a sheet version constructor
extension BluetoothDeviceView {
    init(bluetoothProvider: BluetoothDeviceProvider, heartRateProvider: HeartRateProvider, isSheet: Bool = false) {
        self.bluetoothProvider = bluetoothProvider
        self.heartRateProvider = heartRateProvider
        self.isSheet = isSheet
    }
}

#Preview {
    BluetoothDeviceView(
        bluetoothProvider: BluetoothDeviceProvider(),
        heartRateProvider: HeartRateProvider()
    )
}
