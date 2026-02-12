import Foundation

struct LoginStreakCalculator {
    struct Result {
        let current: Int
        let longest: Int
        let lastLoginDay: Date
        let didChange: Bool
    }

    static func calculate(
        now: Date,
        lastLoginDay: Date?,
        current: Int,
        longest: Int,
        calendar: Calendar = .current
    ) -> Result {
        let today = calendar.startOfDay(for: now)
        let currentValue = max(0, current)
        let longestValue = max(0, longest)

        guard let lastDay = lastLoginDay else {
            let updatedLongest = max(longestValue, 1)
            return Result(current: 1, longest: updatedLongest, lastLoginDay: today, didChange: true)
        }

        let lastDayStart = calendar.startOfDay(for: lastDay)
        if lastDayStart == today {
            return Result(current: currentValue, longest: longestValue, lastLoginDay: lastDayStart, didChange: false)
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        if lastDayStart == yesterday {
            let newCurrent = max(1, currentValue + 1)
            let newLongest = max(longestValue, newCurrent)
            return Result(current: newCurrent, longest: newLongest, lastLoginDay: today, didChange: true)
        }

        let newLongest = max(longestValue, 1)
        return Result(current: 1, longest: newLongest, lastLoginDay: today, didChange: true)
    }
}
