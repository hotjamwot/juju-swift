import SwiftUI

struct TooltipView: View {
    let projectName: String
    let hours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(projectName)
                .font(.caption)
                .bold()
                .foregroundColor(.white)

            Text("\(Int(hours))h \(Int((hours * 60).truncatingRemainder(dividingBy: 60)))m")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Theme.Colors.background)
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}
