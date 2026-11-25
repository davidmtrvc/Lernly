import SwiftUI

nonisolated enum CourseColor: String, CaseIterable, Codable, Identifiable, Hashable {
    case indigo, blue, teal, green, orange, red, pink, purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .indigo: Color(red: 0.36, green: 0.35, blue: 0.95)
        case .blue: Color(red: 0.13, green: 0.55, blue: 0.95)
        case .teal: Color(red: 0.07, green: 0.68, blue: 0.68)
        case .green: Color(red: 0.24, green: 0.72, blue: 0.36)
        case .orange: Color(red: 0.98, green: 0.58, blue: 0.13)
        case .red: Color(red: 0.93, green: 0.30, blue: 0.33)
        case .pink: Color(red: 0.93, green: 0.36, blue: 0.62)
        case .purple: Color(red: 0.62, green: 0.36, blue: 0.90)
        }
    }

    var shadow: Color { color.mix(with: .black, by: 0.25) }
}

nonisolated enum CourseIcons {
    static let all = [
        "atom", "function", "flask.fill", "globe.europe.africa.fill", "book.fill", "leaf.fill",
        "brain.head.profile", "character.book.closed.fill", "chart.bar.fill", "building.columns.fill",
        "music.note", "paintpalette.fill", "cpu.fill", "heart.fill", "sum", "hammer.fill",
        "bolt.fill", "pawprint.fill", "scroll.fill", "laptopcomputer", "cross.case.fill",
        "dollarsign.circle.fill", "text.book.closed.fill", "lightbulb.fill",
    ]
}
