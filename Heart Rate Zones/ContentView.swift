//
//  ContentView.swift
//  Heart Rate Zones
//
//  Created by Kevin Chromik on 06.03.25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var heartRateProvider = HeartRateProvider()
    @State private var showOnboarding = true
    @State private var showZoneEditor = false
    @State private var animateHeartbeat = false
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 30) {
                // Heart rate display
                heartRateView
                
                // Zones display
                zonesView
                
                // Edit zones button
                Button(action: {
                    showZoneEditor = true
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit Zones")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                }
                .padding(.top, 10)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundGradient)
            
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
        .preferredColorScheme(.dark)
    }
    
    // Heart rate display with animation
    private var heartRateView: some View {
        VStack(spacing: 15) {
            Text(heartRateProvider.currentZone.name)
                .font(.headline)
                .foregroundColor(heartRateProvider.currentZone.color)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(heartRateProvider.currentZone.color.opacity(0.2))
                .cornerRadius(20)
                .animation(.spring(response: 0.5), value: heartRateProvider.currentZone.id)
            
            ZStack {
                // Pulse animation
                Circle()
                    .fill(heartRateProvider.currentZone.color.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animateHeartbeat ? 1.1 : 1.0)
                    .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateHeartbeat)
                
                // Heart rate display
                VStack(spacing: 0) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(heartRateProvider.currentZone.color)
                        .scaleEffect(animateHeartbeat ? 1.1 : 1.0)
                        .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateHeartbeat)
                    
                    Text("\(heartRateProvider.currentRate)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("BPM")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .onAppear {
                animateHeartbeat = true
            }
        }
        .padding(.top, 40)
    }
    
    // Zones visualization
    private var zonesView: some View {
        VStack(spacing: 15) {
            Text("Heart Rate Zones")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(heartRateProvider.zones) { zone in
                    ZoneRowView(zone: zone, currentRate: heartRateProvider.currentRate, isActive: zone.id == heartRateProvider.currentZone.id)
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
        }
    }
    
    // Background gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(#colorLiteral(red: 0.09019608051, green: 0.09019608051, blue: 0.09019608051, alpha: 1)), Color(#colorLiteral(red: 0.1764705926, green: 0.1764705926, blue: 0.1764705926, alpha: 1))]),
            startPoint: .top,
            endPoint: .bottom
        )
        .edgesIgnoringSafeArea(.all)
    }
}

// Individual zone row component
struct ZoneRowView: View {
    let zone: HeartRateZone
    let currentRate: Int
    let isActive: Bool
    
    var body: some View {
        HStack {
            // Zone indicator
            Circle()
                .fill(zone.color)
                .frame(width: 12, height: 12)
            
            // Zone name
            Text(zone.name.replacingOccurrences(of: "Zone \\d+ - ", with: "", options: .regularExpression))
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            // Zone range
            Text("\(zone.startRate)+ BPM")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? zone.color.opacity(0.3) : Color.clear)
        )
        .animation(.spring(response: 0.3), value: isActive)
    }
}

#Preview {
    ContentView()
}
