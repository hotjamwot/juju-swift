import SwiftUI

struct BubbleChartView: View {
    let bubbleData: [BubbleChartData]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                Color.black.opacity(0.95)
                    .frame(height: 300)
                
                // Month dividers
                ForEach(1..<12, id: \.self) { month in
                    let monthWidth = geometry.size.width / 12
                    let x = CGFloat(month) * monthWidth
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1)
                        .position(x: x, y: 0)
                        .frame(maxHeight: .infinity)
                }
                
                // Bubbles
                ForEach(bubbleData) { bubble in
                    Circle()
                        .fill(bubble.color.opacity(bubble.opacity))
                        .frame(width: bubble.diameter, height: bubble.diameter)
                        .position(x: bubble.x + bubble.diameter/2, y: bubble.y + bubble.diameter/2)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.25), lineWidth: 1)
                                .opacity(bubble.shadow ? 1 : 0)
                        )
                }
            }
        }
    }
}

#Preview {
    let sampleBubbleData = [
        BubbleChartData(
            x: 100,
            y: 50,
            diameter: 20,
            color: Color.blue,
            opacity: 0.8,
            shadow: false
        ),
        BubbleChartData(
            x: 300,
            y: 100,
            diameter: 15,
            color: Color.orange,
            opacity: 0.6,
            shadow: true
        )
    ]
    
    return BubbleChartView(bubbleData: sampleBubbleData)
        .frame(width: 1000, height: 300)
        .padding()
}
