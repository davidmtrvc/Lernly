import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store

    private var streak: Int { store.stats.currentStreak() }
    private var todayDone: Int { store.stats.lessons(on: .now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    streakCard
                    goalCard
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        statTile("bolt.fill", "\(store.stats.totalXP)", "Gesamt-XP", Theme.xp)
                        statTile("trophy.fill", "\(store.stats.longestStreak)", "Längster Streak", Theme.flame)
                        statTile("checkmark.seal.fill", "\(store.stats.lessonsCompleted)", "Lektionen", Theme.correct)
                        statTile("books.vertical.fill", "\(store.courses.count)", "Kurse", Theme.primary)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profil")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var streakCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(streak > 0 ? Theme.flame : .secondary)
                        .contentTransition(.numericText())
                    Text(streak == 1 ? "Tag in Folge" : "Tage in Folge")
                        .font(.headline)
                    Text(store.stats.isActive(.now) ? "Heute geschafft – bis morgen!" :
                            streak > 0 ? "Mach heute eine Lektion, um deinen Streak zu halten." : "Starte heute deinen Streak.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(store.stats.isActive(.now) ? AnyShapeStyle(Theme.flame.gradient) : AnyShapeStyle(Color(.systemGray4)))
                    .symbolEffect(.bounce, value: streak)
            }
            WeekStrip(stats: store.stats)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var goalCard: some View {
        let goal = store.stats.dailyGoal
        let progress = min(Double(todayDone) / Double(goal), 1)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.correct, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: progress >= 1 ? "checkmark" : "target")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.correct)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tagesziel")
                    .font(.headline)
                Text("\(min(todayDone, goal)) von \(goal) \(goal == 1 ? "Lektion" : "Lektionen") heute")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func statTile(_ icon: String, _ value: String, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.heavy))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Die aktuelle Woche (Mo–So) mit erledigten Tagen.
struct WeekStrip: View {
    var stats: UserStats

    private var days: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offset, to: today) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        let labels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let active = stats.isActive(day)
                let isToday = Calendar.current.isDateInToday(day)
                VStack(spacing: 6) {
                    Text(labels[index])
                        .font(.caption.weight(isToday ? .heavy : .semibold))
                        .foregroundStyle(isToday ? .primary : .secondary)
                    ZStack {
                        Circle()
                            .fill(active ? Theme.flame : Color(.systemGray6))
                        if active {
                            Image(systemName: "flame.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .overlay {
                        if isToday && !active {
                            Circle().strokeBorder(Theme.flame.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
