import SwiftUI

struct SummaryMetricView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .center, spacing: Theme.spacingMedium) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [
                        Theme.Colors.accentColor,
                        Theme.Colors.accentColor.opacity(0.7)
                    ],
                    startPoint: .leading, endPoint: .trailing
                ))
        }
        .frame(maxWidth: .infinity) // Ensure it takes full width for proper centering
    }
}
