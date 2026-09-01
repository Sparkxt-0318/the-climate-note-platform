import SwiftUI

struct MyNoteView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var reflections: ReflectionStore
    @State private var showSignIn = false

    var body: some View {
        Group {
            if auth.user == nil {
                ContentUnavailableView {
                    Label("Your climate note", systemImage: "leaf")
                } description: {
                    Text("Sign in to keep your actions private and see your weekly progress.")
                } actions: {
                    Button("Sign in") { showSignIn = true }.buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        if let error = reflections.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(.background, in: .rect(cornerRadius: 20))
                        }
                        WeekCalendar(completedDates: reflections.logs.compactMap(\.completedAt))
                        impactCard
                        ForEach(reflections.logs) { log in ActionLogCard(log: log) }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle("My Note")
        .background(Color.climateBackground)
        .sheet(isPresented: $showSignIn) { SignInView() }
    }

    private var impactCard: some View {
        let completed = reflections.logs.filter { $0.status == .completed }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Your impact").font(.headline)
            Text("\(completed.count)").font(.system(size: 46, weight: .bold, design: .rounded)).foregroundStyle(Color.climateSage)
            Text(completed.count == 1 ? "climate action completed" : "climate actions completed")
                .foregroundStyle(.secondary)
            if !completed.compactMap(\.impactEstimate).isEmpty {
                Text("\(completed.compactMap(\.impactEstimate).reduce(0) { $0 + $1.value }.formatted(.number.precision(.fractionLength(0...2)))) kg CO₂e")
                    .font(.title3.bold())
                Text("estimated from supported actions")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("CO₂ estimates appear only when the action matches a verified impact factor.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.background, in: .rect(cornerRadius: 24))
    }
}

private struct WeekCalendar: View {
    let completedDates: [Date]
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This week").font(.headline)
            HStack {
                ForEach(days, id: \.self) { day in
                    let completed = completedDates.contains { calendar.isDate($0, inSameDayAs: day) }
                    VStack(spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption)
                        Text(day.formatted(.dateTime.day()))
                            .font(.subheadline.bold())
                            .frame(width: 38, height: 38)
                            .background(completed ? Color.climateSage : Color.secondary.opacity(0.1), in: .circle)
                            .foregroundStyle(completed ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(day.formatted(.dateTime.weekday(.wide).month().day())), \(completed ? "action completed" : "no completed action")"
                    )
                }
            }
        }
        .padding(22)
        .background(.background, in: .rect(cornerRadius: 24))
    }

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let start = calendar.date(byAdding: .day, value: -(weekday - calendar.firstWeekday + 7) % 7, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

private struct ActionLogCard: View {
    let log: ActionLog
    @EnvironmentObject private var reflections: ReflectionStore
    @EnvironmentObject private var notifications: NotificationService
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(log.title).font(.headline)
                Spacer()
                Image(systemName: log.status == .completed ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(Color.climateSage)
                    .accessibilityLabel(log.status == .completed ? "Completed" : "Planned")
            }
            Text(log.detail).foregroundStyle(.secondary)
            Text(log.articleTitle).font(.caption).foregroundStyle(.secondary)
            if log.status == .planned {
                ViewThatFits(in: .horizontal) {
                    HStack { actionButtons }
                    VStack(alignment: .leading) { actionButtons }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: .rect(cornerRadius: 20))
        .alert("Action problem", isPresented: Binding(
            get: { errorMessage != nil || notifications.errorMessage != nil },
            set: { if !$0 { errorMessage = nil; notifications.errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
                notifications.errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? notifications.errorMessage ?? "Please try again.")
        }
    }

    @ViewBuilder private var actionButtons: some View {
        Button("Mark as achieved") {
            Task {
                do {
                    try await reflections.complete(log)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .buttonStyle(.borderedProminent)
        Button("Remind me") {
            Task { await notifications.scheduleActionReminder(for: log) }
        }
        .buttonStyle(.bordered)
    }
}
