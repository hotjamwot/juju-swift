import SwiftUI

struct ProjectGridItemView: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: project.color))
                .frame(height: 100)
                .overlay(
                    Text(project.name.prefix(1).uppercased())
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text(project.name)
                .lineLimit(1)
                .font(.headline)
            
            if let about = project.about, !about.isEmpty {
                Text(about)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(Theme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}