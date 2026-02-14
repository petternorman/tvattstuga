import Foundation
import SwiftUI

enum MachineDisplayState: String {
    case available
    case taken
    case notBookable = "not_bookable"
    case recentlyUsed = "recently_used"
    case unknown

    var title: String {
        switch self {
        case .available:
            return "Available"
        case .taken:
            return "Busy"
        case .notBookable:
            return "Not bookable"
        case .recentlyUsed:
            return "Recently used"
        case .unknown:
            return "Unknown"
        }
    }

    var tintColor: Color {
        switch self {
        case .available:
            return .green
        case .taken:
            return .orange
        case .notBookable:
            return .red
        case .recentlyUsed:
            return .mint
        case .unknown:
            return .gray
        }
    }
}

extension Machine {
    func displayState(referenceDate: Date = .now) -> MachineDisplayState {
        let mapped = MachineDisplayState(rawValue: state) ?? .unknown
        if mapped == .available, wasRecentlyUsed(referenceDate: referenceDate) {
            return .recentlyUsed
        }
        return mapped
    }

    func detailLine(referenceDate: Date = .now) -> String {
        guard !status.isEmpty else {
            return "No status reported."
        }

        guard let completionDate = completionDate(referenceDate: referenceDate) else {
            return status
        }

        let secondsRemaining = Int(completionDate.timeIntervalSince(referenceDate))
        if secondsRemaining <= 0 {
            return "\(status) (ready)"
        }
        return "\(status) (\(formatDuration(secondsRemaining)) left)"
    }

    func completionDate(referenceDate: Date = .now) -> Date? {
        parseClockTime(
            in: status,
            regexPattern: #"klar ca:\s*(\d{1,2}):(\d{2})"#,
            referenceDate: referenceDate,
            moveToNextDayIfPast: true
        )
    }

    func wasRecentlyUsed(referenceDate: Date = .now) -> Bool {
        guard let completedAt = parseClockTime(
            in: status,
            regexPattern: #"avslutades\s*(\d{1,2}):(\d{2})"#,
            referenceDate: referenceDate,
            moveToNextDayIfPast: false
        ) else {
            return false
        }

        let diff = referenceDate.timeIntervalSince(completedAt)
        return diff >= 0 && diff <= 3600
    }
}

extension ResourceGroup {
    func availableCount(referenceDate: Date = .now) -> Int {
        machines.filter {
            let state = $0.displayState(referenceDate: referenceDate)
            return state == .available || state == .recentlyUsed
        }.count
    }
}

private func parseClockTime(
    in text: String,
    regexPattern: String,
    referenceDate: Date,
    moveToNextDayIfPast: Bool
) -> Date? {
    guard
        let regex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive]),
        let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
        let hourRange = Range(match.range(at: 1), in: text),
        let minuteRange = Range(match.range(at: 2), in: text),
        let hour = Int(text[hourRange]),
        let minute = Int(text[minuteRange])
    else {
        return nil
    }

    var calendar = Calendar.current
    calendar.timeZone = .current

    guard var date = calendar.date(
        bySettingHour: hour,
        minute: minute,
        second: 0,
        of: referenceDate
    ) else {
        return nil
    }

    if moveToNextDayIfPast && date <= referenceDate {
        date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
    }

    return date
}

private func formatDuration(_ seconds: Int) -> String {
    if seconds < 60 {
        return "\(seconds)s"
    }

    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    if remainingSeconds == 0 {
        return "\(minutes)m"
    }

    return "\(minutes)m \(remainingSeconds)s"
}
