import Foundation

enum Streaks {
    /// Number of consecutive calendar days with at least one date, counting back from today.
    /// A streak that last happened yesterday still counts, since today isn't over yet.
    static func consecutiveDays(_ dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        var check = calendar.startOfDay(for: now)
        if !days.contains(check) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: check),
                  days.contains(yesterday) else { return 0 }
            check = yesterday
        }
        var streak = 0
        while days.contains(check) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: check) else { break }
            check = previous
        }
        return streak
    }
}

extension Streaks {
    /// Number of consecutive calendar weeks with at least one date, counting back from this week.
    /// Last week still counts while the current week has no entry yet.
    static func consecutiveWeeks(_ dates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        func weekStart(_ date: Date) -> Date? {
            calendar.dateInterval(of: .weekOfYear, for: date)?.start
        }
        let weeks = Set(dates.compactMap(weekStart))
        guard var check = weekStart(now) else { return 0 }
        if !weeks.contains(check) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: check), weeks.contains(previous) else { return 0 }
            check = previous
        }
        var streak = 0
        while weeks.contains(check) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: check) else { break }
            check = previous
        }
        return streak
    }
}
