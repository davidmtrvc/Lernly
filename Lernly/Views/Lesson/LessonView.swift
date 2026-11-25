import SwiftUI

struct LessonLaunch: Identifiable {
    let id = UUID()
    var courseID: UUID
    var chapterTitle: String
    var lesson: Lesson
    var color: CourseColor
}

struct LessonView: View {
    let launch: LessonLaunch
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var session: LessonSession
    @State private var reward: LessonReward?
    @State private var confirmExit = false

    init(launch: LessonLaunch) {
        self.launch = launch
        _session = State(initialValue: LessonSession(lesson: launch.lesson))
    }

    private var color: Color { launch.color.color }

    var body: some View {
        Group {
            if let reward {
                LessonCompleteView(reward: reward, lessonTitle: launch.lesson.title, color: color) { dismiss() }
                    .transition(.opacity)
            } else {
                lessonBody
            }
        }
        .background(Color(.systemBackground))
        .onAppear { if session.finished { complete() } }
        .onChange(of: session.finished) { _, finished in if finished { complete() } }
        .sensoryFeedback(trigger: session.feedback?.id) { _, _ in
            guard let feedback = session.feedback else { return nil }
            return feedback.isCorrect ? .success : .error
        }
    }

    private var lessonBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    if session.doneUnits == 0 { dismiss() } else { confirmExit = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                ProgressCapsule(value: session.progress, color: color, height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                if let item = session.current {
                    itemView(item)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .id(item.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
        .confirmationDialog("Lektion beenden?", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("Beenden", role: .destructive) { dismiss() }
            Button("Weiterlernen", role: .cancel) {}
        } message: {
            Text("Dein Fortschritt in dieser Lektion geht verloren.")
        }
    }

    // MARK: Inhalt

    @ViewBuilder
    private func itemView(_ item: LessonSession.Item) -> some View {
        switch item {
        case .theory(let card, let index):
            TheoryCardView(card: card, number: index + 1, total: launch.lesson.theory.count, color: color)
        case .exercise(let exercise, let attempt):
            exerciseView(exercise, isRetry: attempt > 0)
        }
    }

    @ViewBuilder
    private func exerciseView(_ exercise: Exercise, isRetry: Bool) -> some View {
        let locked = session.feedback != nil
        switch exercise.kind {
        case .singleChoice(let question, let options, let answer):
            SingleChoiceView(question: question, options: options, answer: answer, draft: $session.draft, locked: locked, isRetry: isRetry)
        case .multipleChoice(let question, let options, let answers):
            MultipleChoiceView(question: question, options: options, answers: answers, draft: $session.draft, locked: locked, isRetry: isRetry)
        case .trueFalse(let statement, let answer):
            TrueFalseView(statement: statement, answer: answer, draft: $session.draft, locked: locked, isRetry: isRetry)
        case .input(let question, _):
            InputExerciseView(question: question, draft: $session.draft, locked: locked, isRetry: isRetry) {
                check()
            }
        case .cloze(let text, _):
            ClozeView(text: text, draft: $session.draft, locked: locked, isRetry: isRetry)
        case .order(let question, let items):
            OrderView(question: question, items: items, draft: $session.draft, locked: locked, isRetry: isRetry)
        case .match(let question, let pairs):
            MatchView(question: question, pairs: pairs, draft: $session.draft, locked: locked, isRetry: isRetry) {
                withAnimation(.spring(duration: 0.35)) { session.finishMatch() }
            }
        case .flashcard(let front, let back):
            FlashcardView(front: front, back: back, draft: $session.draft, isRetry: isRetry, color: color)
        }
    }

    // MARK: Fußleiste

    @ViewBuilder
    private var footer: some View {
        if let feedback = session.feedback {
            FeedbackPanel(feedback: feedback) { next() }
                .transition(.move(edge: .bottom))
        } else {
            VStack(spacing: 12) {
                switch session.current {
                case .theory:
                    Button("Weiter") { next(theory: true) }
                        .buttonStyle(ChunkyButtonStyle(color: color))
                case .exercise(let exercise, _):
                    switch exercise.kind {
                    case .flashcard:
                        if session.draft.revealed {
                            HStack(spacing: 12) {
                                Button("Nicht gewusst") { rate(false) }
                                    .buttonStyle(OutlineChunkyButtonStyle(tint: Theme.wrong))
                                Button("Gewusst") { rate(true) }
                                    .buttonStyle(ChunkyButtonStyle(color: Theme.correct))
                            }
                        } else {
                            Button("Karte umdrehen") {
                                withAnimation(.spring(duration: 0.5)) { session.draft.revealed = true }
                            }
                            .buttonStyle(ChunkyButtonStyle(color: color))
                        }
                    case .match:
                        Text("Tippe nacheinander auf zwei passende Kärtchen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(height: 54)
                    default:
                        Button("Prüfen") { check() }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.correct))
                            .disabled(!session.canCheck)
                    }
                case nil:
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .overlay(alignment: .top) { Divider() }
        }
    }

    private func check() {
        guard session.canCheck else { return }
        withAnimation(.spring(duration: 0.35)) { session.check() }
    }

    private func rate(_ knewIt: Bool) {
        withAnimation(.spring(duration: 0.35)) { session.rateFlashcard(knewIt: knewIt) }
    }

    private func next(theory: Bool = false) {
        withAnimation(.spring(duration: 0.4)) {
            if theory { session.continueTheory() } else { session.advance() }
        }
    }

    private func complete() {
        guard reward == nil else { return }
        let result = store.completeLesson(launch.lesson.id, in: launch.courseID, accuracy: session.accuracy)
        withAnimation(.easeInOut(duration: 0.3)) { reward = result }
    }
}

// MARK: - Feedback

struct FeedbackPanel: View {
    var feedback: Feedback
    var onContinue: () -> Void

    private var tint: Color { feedback.isCorrect ? Theme.correct : Theme.wrong }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                Text(feedback.title)
                    .font(.title2.weight(.heavy))
            }
            .foregroundStyle(tint)

            if let answer = feedback.correctAnswer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Richtige Antwort:")
                        .font(.subheadline.weight(.bold))
                    Text(md(answer))
                        .font(.subheadline)
                }
                .foregroundStyle(tint.mix(with: .primary, by: 0.35))
            }
            if let note = feedback.note {
                Text(note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint.mix(with: .primary, by: 0.35))
            }
            if let explanation = feedback.explanation {
                Text(md(explanation))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(feedback.isCorrect ? "Weiter" : "Verstanden", action: onContinue)
                .buttonStyle(ChunkyButtonStyle(color: tint))
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.14).ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Abschluss

struct LessonCompleteView: View {
    var reward: LessonReward
    var lessonTitle: String
    var color: Color
    var onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 190, height: 190)
                    .scaleEffect(appeared ? 1 : 0.4)
                Image(systemName: reward.accuracy >= 0.999 ? "star.circle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(reward.accuracy >= 0.999 ? Theme.xp : color)
                    .symbolEffect(.bounce, value: appeared)
                    .scaleEffect(appeared ? 1 : 0.2)
            }
            VStack(spacing: 8) {
                Text(reward.accuracy >= 0.999 ? "Perfekte Lektion!" : "Lektion geschafft!")
                    .font(.largeTitle.weight(.heavy))
                Text(lessonTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                resultTile(title: "XP", value: "+\(reward.xp)", icon: "bolt.fill", tint: Theme.xp)
                resultTile(title: "Genauigkeit", value: "\(Int((reward.accuracy * 100).rounded()))%", icon: "scope", tint: Theme.correct)
                resultTile(title: "Streak", value: "\(reward.streak)", icon: "flame.fill", tint: Theme.flame)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            if reward.streakExtended {
                Label(reward.streak == 1 ? "Dein Streak hat begonnen!" : "\(reward.streak) Tage in Folge – weiter so!", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.flame)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.flame.opacity(0.12), in: Capsule())
                    .opacity(appeared ? 1 : 0)
            } else if reward.dailyGoalJustReached {
                Label("Tagesziel erreicht!", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(Theme.correct)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Theme.correct.opacity(0.12), in: Capsule())
                    .opacity(appeared ? 1 : 0)
            }
            Spacer()
            Button("Weiter", action: onDone)
                .buttonStyle(ChunkyButtonStyle(color: color))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.45).delay(0.1)) { appeared = true }
        }
    }

    private func resultTile(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(tint)
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(value)
            }
            .font(.title3.weight(.heavy))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint, lineWidth: 2))
    }
}
