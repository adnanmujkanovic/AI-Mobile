import SwiftUI
import SwiftData
import Charts

struct FastingHistoryView: View {
    @ObservedObject var vm: FastingViewModel
    let profile: UserProfile?
    @Query(sort: \FastingSession.startTime, order: .reverse) private var sessions: [FastingSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var finishedSessions: [FastingSession] { sessions.filter { $0.isFinished } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: FDSpacing.sm) {
                        FDStatCard(
                            title: "Fasts",
                            value: "\(finishedSessions.count)",
                            unit: "",
                            icon: "moon.fill",
                            color: .fdIndigo
                        )
                        FDStatCard(
                            title: "7-day avg",
                            value: String(format: "%.1f", vm.weeklyAverageFastingHours(sessions: finishedSessions)),
                            unit: "h",
                            icon: "clock.fill",
                            color: .fdBlue
                        )
                        FDStatCard(
                            title: "Streak",
                            value: "\(vm.consecutiveStreak(sessions: sessions, profile: profile))",
                            unit: "days",
                            icon: "flame.fill",
                            color: .fdOrange
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if !finishedSessions.isEmpty {
                    Section("Last 14 fasts") {
                        FastingHistoryChart(sessions: Array(finishedSessions.prefix(14)))
                            .frame(height: 160)
                            .padding(.vertical, FDSpacing.sm)
                    }
                }

                Section {
                    if finishedSessions.isEmpty {
                        ContentUnavailableView(
                            "No Fasts Yet",
                            systemImage: "moon.zzz.fill",
                            description: Text("Finish your first fast to see it here.")
                        )
                    } else {
                        ForEach(finishedSessions) { session in
                            FastHistoryDetailRow(session: session)
                        }
                        .onDelete { offsets in
                            offsets.map { finishedSessions[$0] }.forEach { modelContext.delete($0) }
                            modelContext.saveOrLog()
                        }
                    }
                } header: {
                    Text("History")
                } footer: {
                    if !finishedSessions.isEmpty {
                        Text("Swipe left on a fast to delete it.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Fasting History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FastingHistoryChart: View {
    let sessions: [FastingSession]

    var body: some View {
        Chart {
            ForEach(sessions.reversed()) { session in
                BarMark(
                    x: .value("Date", session.startTime, unit: .day),
                    y: .value("Hours", session.actualHours)
                )
                .foregroundStyle(session.completed ? Color.fdGreen : Color.fdOrange)
                .cornerRadius(4)
            }
            if let typical = sessions.first?.plannedHours {
                RuleMark(y: .value("Goal", typical))
                    .foregroundStyle(Color.fdSecondaryLabel)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel { if let h = value.as(Double.self) { Text("\(Int(h))h") } }
            }
        }
        .accessibilityLabel("Chart of your last \(sessions.count) fasts in hours")
    }
}

struct FastHistoryDetailRow: View {
    let session: FastingSession

    var completionRate: Double {
        guard session.plannedHours > 0 else { return 0 }
        return min(1.0, session.actualHours / Double(session.plannedHours))
    }

    var stage: FastingStage { FastingStage.forHours(session.actualHours) }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.startTime, style: .date)
                        .font(.fdSubheadline)
                    Text(session.startTime, style: .time)
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(FastingViewModel.formatHours(session.actualHours))
                            .font(.fdTitle3)
                            .foregroundColor(session.completed ? .fdGreen : .fdOrange)
                        if session.completed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.fdGreen)
                        }
                    }
                    Text("goal \(session.plannedHours)h")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.fdSecondaryLabel.opacity(0.15))
                    Capsule()
                        .fill(session.completed ? Color.fdGreen : Color.fdOrange)
                        .frame(width: geo.size.width * completionRate)
                }
            }
            .frame(height: 6)

            HStack {
                Image(systemName: stage.icon)
                    .font(.caption)
                    .foregroundColor(stage.swiftUIColor)
                Text("Reached: \(stage.rawValue)")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
