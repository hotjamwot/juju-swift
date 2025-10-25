import SwiftUI

/// 1️⃣  What we want to show in the sidebar
enum DashboardView: String, CaseIterable, Identifiable {
    case charts   = "Charts"
    case sessions = "Sessions"
    case projects = "Projects"

    // MARK: - Icons
    var icon: String {
        switch self {
        case .charts:   return "chart.xyaxis.line"
        case .sessions: return "clock"
        case .projects: return "folder"
        }
    }

    // Required by Identifiable
    var id: String { rawValue }
}

// MARK: ── Sidebar button (re‑usable)
struct SidebarButton: View {
    @Binding var selected: DashboardView   // the parent’s selection state
    let target: DashboardView              // the view that this button represents

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            // ❗️  Selection – this drives the right‑hand panel
            selected = target
        } label: {
            HStack(spacing: 12) {
                Image(systemName: target.icon)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)

                Text(target.rawValue)
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .accentColor : .primary))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    if isSelected {          // ✅  Selected colour
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.accentColor)
                            .shadow(color: Color.accentColor.opacity(0.3),
                                    radius: 3, x: 0, y: 1.5)
                    } else if isHovered {     // ☁️  Hover reveal
                        RoundedRectangle(cornerRadius: 7)
                            .fill(colorScheme == .dark ?
                                  Color.white.opacity(0.06) :
                                  Color.black.opacity(0.04))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in               // Detect root‑view hover
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var isSelected: Bool { selected == target }
}

// MARK: ── The split‑view container

struct SidebarView: View {
    @Binding var selectedView: DashboardView

    var body: some View {
        VStack(spacing: 4) {
            // ── optional header / app icon
            HStack {
                if let img = NSImage(named: "AppIcon") {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text("Juju")
                    .font(.system(.subheadline, weight: .bold))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.thinMaterial)   // macOS‑style blur

            // ── the list of buttons
            ForEach(DashboardView.allCases) { view in
                SidebarButton(selected: $selectedView, target: view)
                    .accessibilityLabel(view.rawValue)
            }

            Spacer()
        }
        .frame(width: 170)                          // Fixed width
        .background(.thinMaterial)                  // Hover/selection blend
    }
}

// MARK: ── Preview (optional)

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selectedView: .constant(.charts))
            .frame(minWidth: 800, minHeight: 500)
    }
}
