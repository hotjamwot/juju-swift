// YearlyDashboardView.swift
// Juju
//
// Created by Hayden on 12/12/2025.
//

import SwiftUI

/// Placeholder Yearly Dashboard View
/// This will be the dedicated view for all yearly charts and metrics
/// Currently contains placeholder content until Phase 3 implementation
struct YearlyDashboardView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Floating navigation button (always visible in center-right, same position as weekly, even closer to edge)
                Button(action: {
                    NotificationCenter.default.post(name: .switchToWeeklyView, object: nil)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.navigation) // Use shared NavigationButtonStyle
                .help("Back to Weekly Dashboard")
                .position(x: geometry.size.width - 16, y: geometry.size.height / 2)
                .zIndex(2)
                
                // Main content
                VStack(spacing: 20) {
                    // Title header
                    Text("Yearly Dashboard")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top, Theme.spacingLarge)
                    
                    // Placeholder content area
                    VStack(spacing: 16) {
                        Text("Yearly Dashboard Coming Soon")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text("This will contain:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Yearly Total Bar Chart (Projects)")
                                .padding(.leading, 8)
                            Text("• 52-Week Stacked Bar Chart")
                                .padding(.leading, 8)
                            Text("• Activity Type Breakdown")
                                .padding(.leading, 8)
                            Text("• Summary Metrics")
                                .padding(.leading, 8)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
            }
        }
    }
}

#Preview {
    YearlyDashboardView()
}
