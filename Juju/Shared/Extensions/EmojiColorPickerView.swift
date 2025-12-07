import SwiftUI

/// Reusable emoji picker component for selecting emojis
struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String
    @State private var searchText: String = ""
    
    // Use the new EmojiItem structure for proper SwiftUI rendering
    var filteredEmojiItems: [EmojiItem] {
        if searchText.isEmpty {
            return EmojiCatalog.allEmojiItems
        } else {
            return EmojiCatalog.searchEmojiItems(query: searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            HStack {
                Text("Choose an Emoji")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
            }
            
            // Search Bar
            TextField("Search emojis...", text: $searchText)
                .textFieldStyle(.plain)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.spacingMedium)
                .padding(.vertical, Theme.spacingSmall)
                .background(Theme.Colors.surface)
                .cornerRadius(Theme.Design.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius)
                        .stroke(Theme.Colors.divider, lineWidth: 1)
                )
                .padding(.bottom, Theme.spacingMedium)
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: Theme.spacingSmall) {
                    ForEach(filteredEmojiItems) { emojiItem in
                        Button(action: {
                            selectedEmoji = emojiItem.emoji
                            dismiss()
                        }) {
                            Text(emojiItem.emoji)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(selectedEmoji == emojiItem.emoji ? Theme.Colors.surface : Color.clear)
                                .cornerRadius(Theme.Design.cornerRadius / 1.5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Design.cornerRadius / 1.5)
                                        .stroke(selectedEmoji == emojiItem.emoji ? Theme.Colors.accentColor : Theme.Colors.divider,
                                               lineWidth: selectedEmoji == emojiItem.emoji ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .pointingHandOnHover()
                    }
                }
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
}

// MARK: - Color Picker Component (Color-based)
struct ColorPickerViewColor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color
    
    let colorOptions = [
        // Row 1 - Reds & Pinks
        "#FF3366", // Neon rose
        "#E83F6F", // Raspberry punch
        "#FF5C8A", // Hot pink
        "#C41E3A", // Crimson neon
        "#FF7096", // Watermelon
        "#D72638", // Scarlet glow

        // Row 2 - Purples & Blues
        "#8E44AD", // Deep violet
        "#B620E0", // Bright purple
        "#5F0F40", // Plum neon
        "#3A0CA3", // Royal neon blue
        "#4361EE", // Clear azure
        "#4895EF", // Electric sky

        // Row 3 - Greens & Teals
        "#00A896", // Deep teal
        "#06D6A0", // Aqua neon
        "#118AB2", // Ocean blue-green
        "#00B4D8", //Cyan teal
        "#2A9D8F", // Dusty emerald
        "#20C997", // Soft neon jade

        // Row 4 - Yellows & Oranges
        "#E9C46A", // Gold sand
        "#F4A261", // Warm amber
        "#F77F00", // Neon orange
        "#FF9F1C", // Tangerine pop
        "#D98324", // Burnt neon orange
        "#FFB703"  // Golden glow
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            HStack {
                Text("Choose a Color")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
            }
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Theme.spacingSmall) {
                    ForEach(colorOptions, id: \.self) { colorOption in
                        Button(action: {
                            selectedColor = Color(hex: colorOption)
                            dismiss()
                        }) {
                            Circle()
                                .fill(Color(hex: colorOption))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.divider, lineWidth: selectedColor.toHex == colorOption ? 3 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .pointingHandOnHover()
                    }
                }
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
}

// MARK: - Emoji Catalog (Easily Configurable)
// Edit these arrays to customize your emoji options
struct EmojiCategory {
    let name: String
    let emojis: [String]
}

// Individual emoji item with unique identifier for proper SwiftUI rendering
struct EmojiItem: Identifiable, Hashable {
    let id = UUID()
    let character: String
    
    var emoji: String { character }
}

struct EmojiCatalog {
    static let categories = [
        EmojiCategory(
            name: "Work & Business",
            emojis: [
                "💼", "📊", "💻", "📱", "🔧", "⚙️", "📈", "⌨️", "📁", "🗂️", "📋", "📌",
                "💰", "💳", "🏢", "🏪", "💡", "🔍", "📞", "📧", "📨", "📬", "📭", "📣"
            ]
        ),
        EmojiCategory(
            name: "Personal & Lifestyle",
            emojis: [
                "🏠", "👨‍👩‍👧‍👦", "🎨", "🎵", "📚", "🏃‍♂️", "🍳", "🛋️", "🛏️", "🚿", "🎤",
                "🎸", "👟", "🎒", "🕶️", "💄", "💍", "⌚", "🎁", "🎪", "🎭", "🎯", "🎲"
            ]
        ),
        EmojiCategory(
            name: "Learning & Development",
            emojis: [
                "🎓", "💡", "🔬", "📖", "🧠", "💭", "✨", "🎯", "📚", "📝", "🔍", "🧪",
                "⚗️", "🔬", "📐", "📊", "🧮", "🎓", "💭", "💡", "🤓", "🎯", "⭐", "🚀"
            ]
        ),
        EmojiCategory(
            name: "Creative & Design",
            emojis: [
                "🎭", "🎨", "🖌️", "📷", "🎬", "🎥", "🎊", "🎉", "🎨", "🖍️", "✂️", "📐",
                "🎨", "🖼️", "📸", "🎞️", "🎭", "🎪", "🎊", "🎉", "✨", "🌟", "⭐", "💫"
            ]
        ),
        EmojiCategory(
            name: "Nature & Outdoors",
            emojis: [
                "🌱", "🌳", "🌊", "⛰️", "🏔️", "🌸", "🍁", "☀️", "🌿", "🌺", "🌻", "🌼",
                "🌲", "🌴", "🌵", "🌾", "🍃", "🌙", "⭐", "☀️", "🌈", "🌪️", "⛈️", "🌊"
            ]
        ),
        EmojiCategory(
            name: "Food & Drink",
            emojis: [
                "🍕", "🍔", "🍝", "🍰", "☕", "🍷", "🥗", "🍜", "🍳", "🥐", "🥞", "🧇",
                "🍗", "🍖", "🍤", "🦐", "🦀", "🐟", "🥭", "🍎", "🍊", "🍋", "🍌", "🍇"
            ]
        ),
        EmojiCategory(
            name: "Technology & Science",
            emojis: [
                "🤖", "🔬", "⚡", "🚀", "💻", "📡", "🔋", "🛠️", "📱", "⌚", "💾", "💿",
                "🔌", "⚙️", "🔧", "🔨", "🔬", "⚗️", "🧪", "📡", "📡", "🛰️", "🚀", "⚡"
            ]
        ),
        EmojiCategory(
            name: "Sports & Fitness",
            emojis: [
                "⚽", "🏀", "🏃‍♂️", "🏊‍♀️", "🎾", "🏋️‍♀️", "⛷️", "🚴‍♂️", "🏃‍♀️", "🏊‍♂️", "⚽", "🏀",
                "🏈", "⚾", "🎾", "🏐", "🏉", "🥅", "🏓", "🏸", "🎳", "🏹", "🥊", "🥋"
            ]
        ),
        EmojiCategory(
            name: "Travel & Adventure",
            emojis: [
                "✈️", "🗺️", "🏖️", "🏰", "🎒", "🗻", "🌆", "🗽", "🚗", "🚕", "🚙", "🚌",
                "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🛴", "🚲", "🛵", "🏍️", "🚁", "🛸"
            ]
        ),
        EmojiCategory(
            name: "Health & Wellness",
            emojis: [
                "🏥", "💊", "🧘‍♀️", "🧪", "❤️", "💪", "🌟", "🔋", "💆‍♀️", "💆‍♂️", "🧠", "🫀",
                "🫁", "🦴", "🩸", "🩺", "💉", "🧬", "💚", "💛", "💙", "💜", "🧡", "🤍"
            ]
        )
    ]
    
    static var allEmojiItems: [EmojiItem] {
        let allEmojis = categories.flatMap { $0.emojis }
        return allEmojis.map { EmojiItem(character: $0) }
    }
    
    static func searchEmojiItems(query: String) -> [EmojiItem] {
        guard !query.isEmpty else { return allEmojiItems }
        let allEmojis = categories.flatMap { $0.emojis }
        let filteredEmojis = allEmojis.filter { $0.contains(query) }
        return filteredEmojis.map { EmojiItem(character: $0) }
    }
    
    // Legacy support for string-based access
    static var allEmojis: [String] {
        categories.flatMap { $0.emojis }
    }
    
    static func searchEmojis(query: String) -> [String] {
        guard !query.isEmpty else { return allEmojis }
        return allEmojis.filter { $0.contains(query) }
    }
}

// MARK: - Color Picker Component (String-based)
struct ColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: String
    
    let colorOptions = [
        // Row 1 - Reds & Pinks
        "#FF3366", // Neon rose
        "#E83F6F", // Raspberry punch
        "#FF5C8A", // Hot pink
        "#C41E3A", // Crimson neon
        "#FF7096", // Watermelon
        "#D72638", // Scarlet glow

        // Row 2 - Purples & Blues
        "#8E44AD", // Deep violet
        "#B620E0", // Bright purple
        "#5F0F40", // Plum neon
        "#3A0CA3", // Royal neon blue
        "#4361EE", // Clear azure
        "#4895EF", // Electric sky

        // Row 3 - Greens & Teals
        "#00A896", // Deep teal
        "#06D6A0", // Aqua neon
        "#118AB2", // Ocean blue-green
        "#00B4D8", //Cyan teal
        "#2A9D8F", // Dusty emerald
        "#20C997", // Soft neon jade

        // Row 4 - Yellows & Oranges
        "#E9C46A", // Gold sand
        "#F4A261", // Warm amber
        "#F77F00", // Neon orange
        "#FF9F1C", // Tangerine pop
        "#D98324", // Burnt neon orange
        "#FFB703"  // Golden glow
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMedium) {
            HStack {
                Text("Choose a Color")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .pointingHandOnHover()
            }
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Theme.spacingSmall) {
                    ForEach(colorOptions, id: \.self) { colorOption in
                        Button(action: {
                            selectedColor = colorOption
                            dismiss()
                        }) {
                            Circle()
                                .fill(Color(hex: colorOption))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.divider, lineWidth: selectedColor == colorOption ? 3 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .pointingHandOnHover()
                    }
                }
            }
        }
        .padding(Theme.spacingLarge)
        .background(Theme.Colors.background)
    }
}
