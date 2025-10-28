import SwiftUI

struct SummaryMetricView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [
                        Color.accentColor,
                        Color.accentColor.opacity(0.7)
                    ],
                    startPoint: .leading, endPoint: .trailing
                ))
        }
    }
}