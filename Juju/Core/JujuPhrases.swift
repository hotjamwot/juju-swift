import Foundation
import SwiftUI

// MARK: - PhraseTag

enum PhraseTag: String, CaseIterable, Sendable, Codable {
    case greeting
    case morning
    case afternoon
    case evening
    case milestone
    case encouragement
}

// MARK: - Phrase

struct Phrase: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let teReo: String
    let englishGloss: String
    let tags: Set<PhraseTag>

    init(teReo: String, englishGloss: String, tags: Set<PhraseTag>) {
        self.id = UUID()
        self.teReo = teReo
        self.englishGloss = englishGloss
        self.tags = tags
    }
}

// MARK: - TimeOfDay

enum TimeOfDay: Sendable {
    case morning, afternoon, evening

    var tag: PhraseTag {
        switch self {
        case .morning: .morning
        case .afternoon: .afternoon
        case .evening: .evening
        }
    }

    static func current() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }
}

// MARK: - JujuPhrases

struct JujuPhrases {

    public static var userName: String = "Hayden"

    static let catalog: [Phrase] = [
        // Morning greetings
        Phrase(teReo: "Mōrena", englishGloss: "Good morning", tags: [.greeting, .morning]),
        Phrase(teReo: "He rā hou, he rā auaha", englishGloss: "A new day, a creative day", tags: [.greeting, .morning]),

        // Afternoon greetings
        Phrase(teReo: "Kia ora, e te kaituhi", englishGloss: "Hello, writer", tags: [.greeting, .afternoon]),
        Phrase(teReo: "Tēnā koe, e te kaihanga", englishGloss: "Greetings, maker", tags: [.greeting, .afternoon]),

        // General greetings
        Phrase(teReo: "Kia ora", englishGloss: "Hello", tags: [.greeting]),
        Phrase(teReo: "Nau mai, hoki mai", englishGloss: "Welcome back", tags: [.greeting, .encouragement]),
        Phrase(teReo: "I te wā onamata…", englishGloss: "In ancient times…", tags: [.greeting]),

        // Milestone
        Phrase(teReo: "Kua toa koe!", englishGloss: "You champion!", tags: [.milestone, .encouragement]),
        Phrase(teReo: "Kua angitu koe", englishGloss: "You've succeeded", tags: [.milestone, .encouragement]),
        Phrase(teReo: "Whakanuia!", englishGloss: "Celebrate!", tags: [.milestone, .encouragement]),
        Phrase(teReo: "Whakapūmau i tō kōrero", englishGloss: "Make your story endure", tags: [.milestone, .encouragement]),
        Phrase(teReo: "He taonga tō kōrero", englishGloss: "Your story is a treasure", tags: [.milestone, .encouragement]),

        // Encouragement / CTA
        Phrase(teReo: "Kua tae te wā ki te Juju!", englishGloss: "The time for Juju has arrived", tags: [.encouragement]),
        Phrase(teReo: "Kuhu ki te Juju!", englishGloss: "Get into the Juju!", tags: [.encouragement]),
        Phrase(teReo: "Eke ki te Juju!", englishGloss: "Hop aboard the Juju!", tags: [.encouragement]),
        Phrase(teReo: "Me tīmata te Juju!", englishGloss: "Let's get this Juju started!", tags: [.encouragement]),
        Phrase(teReo: "Me tīmata te haerenga", englishGloss: "Let the journey begin", tags: [.encouragement]),
        Phrase(teReo: "Whakamaua tō pene!", englishGloss: "Grab your pen!", tags: [.encouragement]),
        Phrase(teReo: "Kia pai te tuhi", englishGloss: "Happy writing", tags: [.encouragement]),
        Phrase(teReo: "Kia kaha te tuhi", englishGloss: "Stay strong, keep writing", tags: [.encouragement]),
        Phrase(teReo: "Tuhi noa", englishGloss: "Just write", tags: [.encouragement]),
        Phrase(teReo: "Tuhi i nāianei, whakatika ā muri", englishGloss: "Write now, fix later", tags: [.encouragement]),
        Phrase(teReo: "Kaua e whakamā", englishGloss: "Don't be shy", tags: [.encouragement]),
        Phrase(teReo: "Whakapono ki a koe mātou", englishGloss: "We believe in you", tags: [.encouragement]),
        Phrase(teReo: "Whāia tō moemoeā", englishGloss: "Chase your dream", tags: [.encouragement]),
        Phrase(teReo: "Kia māia", englishGloss: "Be bold", tags: [.encouragement]),
        Phrase(teReo: "Haere tonu", englishGloss: "Keep going", tags: [.encouragement]),
        Phrase(teReo: "Kōkiri!", englishGloss: "Press on!", tags: [.encouragement]),
        Phrase(teReo: "Kia kaha", englishGloss: "Stay strong", tags: [.encouragement]),
        Phrase(teReo: "Kia pai tō moe, e te kaituhi", englishGloss: "Sleep well, writer", tags: [.encouragement, .evening]),
        Phrase(teReo: "E te pūkōrero…", englishGloss: "O storyteller…", tags: [.greeting, .encouragement]),
        Phrase(teReo: "Rarangatia tō kōrero", englishGloss: "Weave your story", tags: [.encouragement]),
        Phrase(teReo: "Kua rere ngā whakaaro", englishGloss: "The ideas are flowing", tags: [.encouragement]),
        Phrase(teReo: "Kia tau ngā whakaaro", englishGloss: "Let thoughts settle", tags: [.encouragement]),
        Phrase(teReo: "Hōparatia te ao", englishGloss: "Explore the world", tags: [.encouragement]),
        Phrase(teReo: "Te Kore → Te Pō → Te Ao Mārama", englishGloss: "Void → Night → World of Light", tags: [.encouragement]),
    ]

    // MARK: - Selection APIs

    static func random(tags: Set<PhraseTag>) -> Phrase? {
        let filtered = catalog.filter { phrase in !phrase.tags.isDisjoint(with: tags) }
        return filtered.randomElement()
    }

    static func greeting(for period: TimeOfDay = .current()) -> Phrase? {
        random(tags: [.greeting, period.tag])
    }

    static func encouragement() -> Phrase? {
        random(tags: [.encouragement])
    }

    static func milestone() -> Phrase? {
        random(tags: [.milestone])
    }

    static func storyLine() -> Phrase? {
        random(tags: [.greeting, .encouragement])
    }

    static func warmWelcome() -> Phrase? {
        random(tags: [.greeting])
    }
}

// MARK: - View Helpers

struct TeReoText: View {
    let phrase: Phrase
    let showGloss: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phrase.teReo)
                .font(Theme.Fonts.affirmation)
            if showGloss {
                Text(phrase.englishGloss)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
            }
        }
    }
}

struct ShimmerTeReoText: View {
    let text: String
    let gloss: String
    
    @State private var pulse = false
    
    var body: some View {
        VStack(alignment: .center, spacing: Theme.Spacing.xs) {
            Text(text)
                .font(Theme.Fonts.header)
            Text(gloss)
                .font(Theme.Fonts.body)
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
        }
        .opacity(pulse ? 1 : 0.7)
        .scaleEffect(pulse ? 1 : 0.97)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct GlossOnHover: View {
    let phrase: Phrase

    @State private var isHovering: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phrase.teReo)
                .font(Theme.Fonts.affirmation)
            if isHovering {
                Text(phrase.englishGloss)
                    .font(Theme.Fonts.caption)
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
