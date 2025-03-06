//
//  OnboardingView.swift
//  Heart Rate Zones
//
//  Created by Cascade on 06.03.25.
//

import SwiftUI

// Helper shape for zone visualization
struct ZoneArc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var color: Color
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        
        return path
    }
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.radians, endAngle.radians) }
        set {
            startAngle = Angle(radians: newValue.first)
            endAngle = Angle(radians: newValue.second)
        }
    }
}

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @ObservedObject var heartRateProvider: HeartRateProvider
    var isEditMode: Bool = false
    
    // State for managing zone configurations
    @State private var customZones: [HeartRateZone] = HeartRateZone.defaultZones
    @State private var currentStep = 0
    
    // Zone colors
    private let zoneColors: [Color] = [.blue, .green, .yellow, .orange, .red]
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                Text("Set Your Heart Rate Zones")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(currentStep >= index ? zoneColors[index] : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                            
                            if currentStep == index {
                                Text("Zone \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(zoneColors[index])
                            }
                        }
                        
                        if index < 4 {
                            Rectangle()
                                .fill(currentStep > index ? zoneColors[index + 1] : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .frame(width: 15)
                        }
                    }
                }
                .padding(.bottom, 30)
                
                if currentStep < 5 {
                    configureZoneView(for: currentStep)
                } else {
                    // Summary view
                    summaryView()
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func configureZoneView(for index: Int) -> some View {
        let zone = customZones[index]
        
        return VStack(spacing: 25) {
            // Zone details with zone number
            VStack(spacing: 8) {
                Text("Zone \(index + 1)")
                    .font(.headline)
                    .foregroundColor(zone.color.opacity(0.8))
                
                Text(zone.name.replacingOccurrences(of: "Zone \\d+ - ", with: "", options: .regularExpression))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(zone.color)
            }
            
            // Zone description based on typical use cases
            Text(zoneDescription(for: index))
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Heart rate slider with dynamic range display
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Starting Heart Rate:")
                        .font(.headline)
                    
                    Text("\(customZones[index].startRate) BPM")
                        .font(.headline)
                        .foregroundColor(zone.color)
                        .fontWeight(.bold)
                }
                
                // Range indicators
                HStack {
                    Text("\(Int(lowerBound(for: index)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(upperBound(for: index)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                
                Slider(value: Binding<Double>(
                    get: { Double(customZones[index].startRate) },
                    set: { 
                        var newZones = customZones
                        newZones[index] = HeartRateZone(
                            name: zone.name,
                            startRate: Int($0),
                            color: zone.color
                        )
                        customZones = newZones
                        
                        // Ensure subsequent zones maintain proper ordering
                        for i in (index + 1)..<newZones.count {
                            if newZones[i].startRate <= newZones[i-1].startRate {
                                newZones[i] = HeartRateZone(
                                    name: newZones[i].name,
                                    startRate: newZones[i-1].startRate + 1,
                                    color: newZones[i].color
                                )
                            }
                        }
                        customZones = newZones
                    }
                ), in: lowerBound(for: index)...upperBound(for: index), step: 1)
                .accentColor(zone.color)
                
                // Zone range preview
                if index < customZones.count - 1 {
                    let nextZoneStart = customZones[index + 1].startRate
                    Text("This zone covers: \(customZones[index].startRate) - \(nextZoneStart - 1) BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                } else {
                    Text("This zone covers: \(customZones[index].startRate)+ BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical)
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button(action: { currentStep -= 1 }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
                
                Button(action: { currentStep += 1 }) {
                    HStack {
                        Text(currentStep < 4 ? "Next" : "Review Zones")
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(zone.color.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .padding()
    }
    
    private func summaryView() -> some View {
        ScrollView {
            VStack(spacing: 25) {
                Text("Your Heart Rate Zones")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Zone visualization
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 220, height: 220)
                    
                    // Create the zone rings
                    ForEach(customZones.indices.reversed(), id: \.self) { index in
                        let zone = customZones[index]
                        let startAngle = angleForHeartRate(zone.startRate)
                        let endAngle = index == 0 ? Angle(degrees: 360) : angleForHeartRate(customZones[index-1].startRate)
                        
                        ZoneArc(startAngle: startAngle, endAngle: endAngle, color: zone.color)
                            .stroke(zone.color, lineWidth: 20)
                            .frame(width: 220, height: 220)
                    }
                    
                    // Max heart rate indicator
                    VStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Max")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .offset(y: -120)
                    
                    // Resting heart rate indicator
                    VStack {
                        Text("Rest")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "heart")
                            .foregroundColor(.blue)
                    }
                    .offset(y: 120)
                }
                .padding(.vertical)
                
                // Zone list
                VStack(spacing: 15) {
                    ForEach(customZones.indices, id: \.self) { index in
                        let zone = customZones[index]
                        let endRate = index < customZones.count - 1 ? customZones[index + 1].startRate - 1 : 220
                        
                        HStack {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 15, height: 15)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Zone \(index + 1): \(zone.name.replacingOccurrences(of: "Zone \\d+ - ", with: "", options: .regularExpression))")
                                    .fontWeight(.medium)
                                
                                Text("\(zone.startRate) - \(endRate) BPM")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { currentStep = index }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(zone.color)
                                    .frame(width: 30, height: 30)
                                    .background(zone.color.opacity(0.1))
                                    .cornerRadius(15)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(zone.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                
                Button(action: {
                    // Update the heart rate provider with custom zones
                    heartRateProvider.updateZones(with: customZones)
                    // Close onboarding
                    showOnboarding = false
                }) {
                    Text(isEditMode ? "Save Changes" : "Start Monitoring")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(
                            gradient: Gradient(colors: [customZones[0].color, customZones[4].color]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding()
        }
    }

    // Helper functions for zone configuration
    func lowerBound(for index: Int) -> Double {
        if index == 0 {
            return 1 // Minimum for the first zone is 1 BPM
        } else {
            return Double(customZones[index - 1].startRate + 1) // Just above previous zone
        }
    }
    
    func upperBound(for index: Int) -> Double {
        return 200 // Maximum for all zones is 200 BPM
    }
    
    func zoneDescription(for index: Int) -> String {
        switch index {
        case 0:
            return "Very light intensity. Perfect for warm-up, recovery, and beginners."
        case 1:
            return "Light intensity. Improves basic endurance and fat burning."
        case 2:
            return "Moderate intensity. Improves aerobic fitness and endurance."
        case 3:
            return "Hard intensity. Increases maximum performance capacity for shorter sessions."
        case 4:
            return "Maximum intensity. For short intervals, improves speed and power."
        default:
            return ""
        }
    }
    
    // Helper to convert heart rate to angle for circular visualization
    func angleForHeartRate(_ rate: Int) -> Angle {
        // Map heart rate range (1-200) to angle (0-360)
        let percentage = Double(rate) / 200.0
        return Angle(degrees: 360 * percentage)
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true), heartRateProvider: HeartRateProvider())
}
