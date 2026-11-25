import SwiftUI

enum Theme {
    static let primary = CourseColor.indigo.color
    static let flame = Color(red: 1.0, green: 0.55, blue: 0.12)
    static let xp = Color(red: 0.98, green: 0.76, blue: 0.10)
    static let correct = Color(red: 0.20, green: 0.74, blue: 0.42)
    static let wrong = Color(red: 0.94, green: 0.32, blue: 0.36)
    static let locked = Color(.systemGray4)
    static let border = Color(.systemGray5)
}

/// Markdown (fett, kursiv, `code`) in Fließtexten aus den Lerndateien.
func md(_ text: String) -> AttributedString {
    (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
        ?? AttributedString(text)
}

// MARK: - Buttons

/// Großer, "drückbarer" Button mit Kante – das typische Lern-App-Gefühl.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.primary
    var foreground: Color = .white
    var depth: CGFloat = 4
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let base = isEnabled ? color : Color(.systemGray5)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        configuration.label
            .font(.headline.weight(.bold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(isEnabled ? foreground : Color(.systemGray2))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .background(shape.fill(base))
            .background(shape.fill(base.mix(with: .black, by: 0.22)).offset(y: pressed ? 0 : depth))
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .animation(.spring(duration: 0.12), value: pressed)
    }
}

/// Sekundärer Button: weiß mit grauem Rand.
struct OutlineChunkyButtonStyle: ButtonStyle {
    var tint: Color = Theme.primary
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        configuration.label
            .font(.headline.weight(.bold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .background(shape.fill(Color(.systemBackground)))
            .overlay(shape.strokeBorder(Theme.border, lineWidth: 2))
            .background(shape.fill(Theme.border).offset(y: pressed ? 0 : 4))
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 4)
            .animation(.spring(duration: 0.12), value: pressed)
    }
}

enum TileState {
    case normal, selected, correct, wrong, disabled
}

/// Auswahlkachel in Übungen.
struct TileButtonStyle: ButtonStyle {
    var state: TileState
    var cornerRadius: CGFloat = 14

    private var stroke: Color {
        switch state {
        case .normal, .disabled: Theme.border
        case .selected: Theme.primary
        case .correct: Theme.correct
        case .wrong: Theme.wrong
        }
    }

    private var fill: Color {
        switch state {
        case .normal, .disabled: .clear
        case .selected: Theme.primary.opacity(0.10)
        case .correct: Theme.correct.opacity(0.12)
        case .wrong: Theme.wrong.opacity(0.12)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && state != .disabled
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .foregroundStyle(state == .disabled ? Color(.systemGray3) : stroke == Theme.border ? Color.primary : stroke)
            .background {
                ZStack {
                    shape.fill(Color(.systemBackground))
                    shape.fill(fill)
                }
            }
            .overlay(shape.strokeBorder(stroke, lineWidth: 2))
            .background(shape.fill(stroke).offset(y: pressed ? 0 : 3))
            .offset(y: pressed ? 3 : 0)
            .padding(.bottom, 3)
            .animation(.spring(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.15), value: state)
    }
}

// MARK: - Bausteine

struct CourseIconTile: View {
    var icon: String
    var color: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

struct ProgressCapsule: View {
    var value: Double
    var color: Color = Theme.primary
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(color)
                    .frame(width: max(value > 0 ? height : 0, geo.size.width * min(max(value, 0), 1)))
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(height: height * 0.25)
                            .padding(.horizontal, height * 0.5)
                            .padding(.top, height * 0.22)
                    }
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.4), value: value)
    }
}

struct StatPill: View {
    var icon: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
        .font(.subheadline.weight(.bold))
    }
}

/// Einfaches Umbruch-Layout für Wortkacheln.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            size.width = min(size.width, maxWidth)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

struct SectionLabel: View {
    var text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
