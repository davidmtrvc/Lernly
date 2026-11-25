import SwiftUI

// MARK: - Gemeinsame Bausteine

struct ExerciseHeader: View {
    var label: String
    var question: String?
    var isRetry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isRetry {
                Label("Fehler von vorhin", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.flame)
            }
            SectionLabel(text: label, color: Theme.primary)
            if let question {
                Text(md(question))
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func tileState(isSelected: Bool, isAnswer: Bool, locked: Bool) -> TileState {
    if locked {
        if isAnswer { return .correct }
        if isSelected { return .wrong }
        return .disabled
    }
    return isSelected ? .selected : .normal
}

// MARK: - Theorie

struct TheoryCardView: View {
    var card: TheoryCard
    var number: Int
    var total: Int
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionLabel(text: "Theorie \(number)/\(total)", color: color)
                Spacer()
                Image(systemName: "lightbulb.max.fill")
                    .foregroundStyle(Theme.xp)
                    .font(.title3)
            }
            if let title = card.title {
                Text(md(title))
                    .font(.title2.weight(.bold))
            }
            Text(md(card.text))
                .font(.body)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(color.opacity(0.25), lineWidth: 2))
    }
}

// MARK: - Single Choice

struct SingleChoiceView: View {
    var question: String
    var options: [String]
    var answer: Int
    @Binding var draft: Draft
    var locked: Bool
    var isRetry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ExerciseHeader(label: "Wähle die richtige Antwort", question: question, isRetry: isRetry)
            VStack(spacing: 12) {
                ForEach(draft.optionOrder, id: \.self) { index in
                    Button {
                        draft.choice = index
                    } label: {
                        Text(md(options[index]))
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .buttonStyle(TileButtonStyle(state: tileState(isSelected: draft.choice == index, isAnswer: index == answer, locked: locked)))
                    .disabled(locked)
                }
            }
        }
    }
}

// MARK: - Multiple Choice

struct MultipleChoiceView: View {
    var question: String
    var options: [String]
    var answers: [Int]
    @Binding var draft: Draft
    var locked: Bool
    var isRetry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ExerciseHeader(label: "Wähle alle richtigen Antworten", question: question, isRetry: isRetry)
            VStack(spacing: 12) {
                ForEach(draft.optionOrder, id: \.self) { index in
                    let selected = draft.multi.contains(index)
                    Button {
                        if selected { draft.multi.remove(index) } else { draft.multi.insert(index) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .font(.title3)
                            Text(md(options[index]))
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                    }
                    .buttonStyle(TileButtonStyle(state: tileState(isSelected: selected, isAnswer: answers.contains(index), locked: locked)))
                    .disabled(locked)
                }
            }
        }
    }
}

// MARK: - Wahr / Falsch

struct TrueFalseView: View {
    var statement: String
    var answer: Bool
    @Binding var draft: Draft
    var locked: Bool
    var isRetry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ExerciseHeader(label: "Wahr oder falsch?", question: nil, isRetry: isRetry)
            Text(md(statement))
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            HStack(spacing: 14) {
                option(true, title: "Wahr", icon: "checkmark")
                option(false, title: "Falsch", icon: "xmark")
            }
        }
    }

    private func option(_ value: Bool, title: String, icon: String) -> some View {
        Button {
            draft.bool = value
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title.weight(.bold))
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
        .buttonStyle(TileButtonStyle(state: tileState(isSelected: draft.bool == value, isAnswer: value == answer, locked: locked)))
        .disabled(locked)
    }
}

// MARK: - Freitext

struct InputExerciseView: View {
    var question: String
    @Binding var draft: Draft
    var locked: Bool
    var isRetry: Bool
    var onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ExerciseHeader(label: "Schreibe die Antwort", question: question, isRetry: isRetry)
            TextField("Deine Antwort", text: $draft.text, axis: .vertical)
                .font(.title3.weight(.semibold))
                .lineLimit(1...4)
                .padding(18)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(focused ? Theme.primary : Theme.border, lineWidth: 2))
                .focused($focused)
                .disabled(locked)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .onChange(of: draft.text) { _, newValue in
                    // Enter in einem mehrzeiligen Feld = Prüfen
                    if newValue.hasSuffix("\n") {
                        draft.text = String(newValue.dropLast())
                        onSubmit()
                    }
                }
        }
        .onAppear { focused = true }
    }
}

// MARK: - Lückentext

struct ClozeView: View {
    var text: String
    @Binding var draft: Draft
    var locked: Bool
    var isRetry: Bool

    private var parsed: (segments: [ClozeSegment], gaps: [String]) { Cloze.parse(text) }

    private struct Token: Identifiable {
        let id: Int
        let kind: Kind
        enum Kind { case word(String), gap(Int) }
    }

    private var tokens: [Token] {
        var result: [Token] = []
        for segment in parsed.segments {
            switch segment {
            case .text(let string):
                for word in string.split(separator: " ", omittingEmptySubsequences: true) {
                    result.append(Token(id: result.count, kind: .word(String(word))))
                }
            case .gap(let index):
                result.append(Token(id: result.count, kind: .gap(index)))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ExerciseHeader(label: "Vervollständige den Text", question: nil, isRetry: isRetry)

            FlowLayout(spacing: 6, lineSpacing: 14) {
                ForEach(tokens) { token in
                    switch token.kind {
                    case .word(let word):
                        Text(md(word)).font(.title3.weight(.medium))
                    case .gap(let index):
                        gapView(index)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            FlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(draft.bank.indices, id: \.self) { index in
                    let used = draft.gapFills.contains(index)
                    Button {
                        if let free = draft.gapFills.firstIndex(where: { $0 == nil }) {
                            draft.gapFills[free] = index
                        }
                    } label: {
                        Text(draft.bank[index])
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .opacity(used ? 0 : 1)
                    }
                    .buttonStyle(TileButtonStyle(state: used ? .disabled : .normal, cornerRadius: 12))
                    .disabled(used || locked)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func gapView(_ index: Int) -> some View {
        if let fill = draft.gapFills[index] {
            let correct = AnswerMatcher.normalize(draft.bank[fill]) == AnswerMatcher.normalize(parsed.gaps[index])
            Button {
                draft.gapFills[index] = nil
            } label: {
                Text(draft.bank[fill])
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(TileButtonStyle(state: locked ? (correct ? .correct : .wrong) : .selected, cornerRadius: 10))
            .disabled(locked)
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray3))
                .frame(width: 64, height: 3)
                .padding(.top, 22)
        }
    }
}

// MARK: - Reihenfolge

struct OrderView: View {
    var question: String
    var items: [String]
    @Binding var draft: Draft
    var locked: Bool
    var isRetry: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ExerciseHeader(label: "Bringe in die richtige Reihenfolge", question: question, isRetry: isRetry)

            VStack(spacing: 10) {
                ForEach(Array(draft.orderPlaced.enumerated()), id: \.element) { position, index in
                    Button {
                        draft.orderPlaced.remove(at: position)
                        draft.orderPool.append(index)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(position + 1)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(.quaternary))
                            Text(md(items[index]))
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                    }
                    .buttonStyle(TileButtonStyle(state: locked ? (index == position ? .correct : .wrong) : .selected))
                    .disabled(locked)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
                ForEach(draft.orderPlaced.count..<items.count, id: \.self) { slot in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .foregroundStyle(Theme.border)
                        .frame(height: 50)
                        .overlay(alignment: .leading) {
                            Text("\(slot + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 22)
                        }
                }
            }

            if !draft.orderPool.isEmpty {
                Divider()
                VStack(spacing: 10) {
                    ForEach(draft.orderPool, id: \.self) { index in
                        Button {
                            draft.orderPool.removeAll { $0 == index }
                            draft.orderPlaced.append(index)
                        } label: {
                            Text(md(items[index]))
                                .font(.body.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                        .buttonStyle(TileButtonStyle(state: .normal))
                        .disabled(locked)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: draft.orderPlaced)
    }
}

// MARK: - Paare zuordnen

struct MatchView: View {
    var question: String
    var pairs: [MatchPair]
    @Binding var draft: Draft
    var locked: Bool
    var isRetry: Bool
    var onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ExerciseHeader(label: "Finde die Paare", question: question, isRetry: isRetry)
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(draft.leftOrder, id: \.self) { index in
                        tile(text: pairs[index].left, index: index, isLeft: true)
                    }
                }
                VStack(spacing: 12) {
                    ForEach(draft.rightOrder, id: \.self) { index in
                        tile(text: pairs[index].right, index: index, isLeft: false)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: draft.matched.count)
        .sensoryFeedback(.error, trigger: draft.matchMistakes)
    }

    private func tile(text: String, index: Int, isLeft: Bool) -> some View {
        let matched = draft.matched.contains(index)
        let selected = isLeft ? draft.selectedLeft == index : draft.selectedRight == index
        let flashing = draft.wrongFlash.contains("\(isLeft ? "l" : "r")\(index)")
        let state: TileState = matched ? .disabled : flashing ? .wrong : selected ? .selected : .normal
        return Button {
            select(index, isLeft: isLeft)
        } label: {
            Text(md(text))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(10)
        }
        .buttonStyle(TileButtonStyle(state: state))
        .disabled(matched || locked)
    }

    private func select(_ index: Int, isLeft: Bool) {
        if isLeft { draft.selectedLeft = index } else { draft.selectedRight = index }
        guard let left = draft.selectedLeft, let right = draft.selectedRight else { return }
        draft.selectedLeft = nil
        draft.selectedRight = nil
        if left == right {
            withAnimation(.easeOut(duration: 0.2)) { _ = draft.matched.insert(left) }
            if draft.matched.count == pairs.count {
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    onComplete()
                }
            }
        } else {
            draft.matchMistakes += 1
            let keys: Set<String> = ["l\(left)", "r\(right)"]
            draft.wrongFlash.formUnion(keys)
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                draft.wrongFlash.subtract(keys)
            }
        }
    }
}

// MARK: - Karteikarte

struct FlashcardView: View {
    var front: String
    var back: String
    @Binding var draft: Draft
    var isRetry: Bool
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ExerciseHeader(label: "Karteikarte – weißt du's?", question: nil, isRetry: isRetry)
            ZStack {
                side(text: front, label: "Frage", tint: color)
                    .opacity(draft.revealed ? 0 : 1)
                side(text: back, label: "Antwort", tint: Theme.correct)
                    .opacity(draft.revealed ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(draft.revealed ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .onTapGesture {
                withAnimation(.spring(duration: 0.5)) { draft.revealed = true }
            }
            if !draft.revealed {
                Text("Überlege dir die Antwort und tippe dann auf die Karte.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func side(text: String, label: String, tint: Color) -> some View {
        VStack(spacing: 14) {
            SectionLabel(text: label, color: tint)
            Text(md(text))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 240)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 2))
    }
}
