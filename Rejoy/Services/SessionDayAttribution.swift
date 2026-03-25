import Foundation
import SwiftData

/// Distributes a session’s practiced duration across calendar days (max 24h wall per day slice, total capped by wall span).
enum SessionDayAttribution {
    /// Walks forward from `start` along wall time until `end`, assigning at most `min(durationSeconds, wallSpan)` seconds.
    static func dayPortions(start: Date, end: Date, durationSeconds: Int, calendar: Calendar) -> [(dayStart: Date, seconds: Int)] {
        guard start < end, durationSeconds > 0 else { return [] }
        let spanSeconds = max(0, Int(end.timeIntervalSince(start)))
        guard spanSeconds > 0 else { return [] }
        let totalToPlace = min(durationSeconds, spanSeconds)

        var remaining = totalToPlace
        var cursor = start
        var chunks: [(dayStart: Date, seconds: Int)] = []

        while remaining > 0, cursor < end {
            guard let interval = calendar.dateInterval(of: .day, for: cursor),
                  let nextMidnight = calendar.date(byAdding: .day, value: 1, to: interval.start) else { break }
            let segmentEnd = min(nextMidnight, end)
            let wallSeconds = segmentEnd.timeIntervalSince(cursor)
            guard wallSeconds > 0 else { break }
            let wallAvailable = Int(floor(wallSeconds))
            guard wallAvailable > 0 else { break }
            let chunk = min(remaining, wallAvailable)
            let dayStart = interval.start
            if let lastIndex = chunks.indices.last,
               calendar.isDate(chunks[lastIndex].dayStart, inSameDayAs: dayStart) {
                chunks[lastIndex].seconds += chunk
            } else {
                chunks.append((dayStart, chunk))
            }
            remaining -= chunk
            cursor = cursor.addingTimeInterval(TimeInterval(chunk))
        }

        return chunks
    }

    /// Seeds for a duration using the same rule as `DedicationView` / live tracking.
    static func seeds(forSeconds seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return seconds * AppSettings.seedsPerSecond
    }

    private static func distributeSeeds(totalSeeds: Int, secondsParts: [Int]) -> [Int] {
        let sumSec = secondsParts.reduce(0, +)
        guard sumSec > 0, !secondsParts.isEmpty else { return secondsParts.map { _ in 0 } }
        var out = secondsParts.map { part in (totalSeeds * part) / sumSec }
        var remainder = totalSeeds - out.reduce(0, +)
        var i = out.count - 1
        while remainder > 0, i >= 0 {
            if secondsParts[i] > 0 {
                out[i] += 1
                remainder -= 1
            }
            i -= 1
        }
        return out
    }

    static func attributedBreakdown(for session: Session, calendar: Calendar) -> [(dayStart: Date, seconds: Int, seeds: Int)] {
        let portions = dayPortions(start: session.startDate, end: session.endDate, durationSeconds: session.durationSeconds, calendar: calendar)
        let seedParts = distributeSeeds(totalSeeds: session.seeds, secondsParts: portions.map(\.seconds))
        return zip(portions, seedParts).map { ($0.dayStart, $0.seconds, $1) }
    }

    static func sessionPortion(_ session: Session, on dayStart: Date, calendar: Calendar) -> (seconds: Int, seeds: Int) {
        let sod = calendar.startOfDay(for: dayStart)
        for row in attributedBreakdown(for: session, calendar: calendar) where calendar.isDate(row.dayStart, inSameDayAs: sod) {
            return (row.seconds, row.seeds)
        }
        return (0, 0)
    }

    /// Same attribution for Supabase rows or synthetic intervals (e.g. live tracking).
    static func portion(
        on dayStart: Date,
        start: Date,
        end: Date,
        durationSeconds: Int,
        totalSeeds: Int,
        calendar: Calendar
    ) -> (seconds: Int, seeds: Int) {
        let portions = dayPortions(start: start, end: end, durationSeconds: durationSeconds, calendar: calendar)
        let seedParts = distributeSeeds(totalSeeds: totalSeeds, secondsParts: portions.map(\.seconds))
        let sod = calendar.startOfDay(for: dayStart)
        for (p, s) in zip(portions, seedParts) where calendar.isDate(p.dayStart, inSameDayAs: sod) {
            return (p.seconds, s)
        }
        return (0, 0)
    }

    static func attributedSeeds(for session: Session, inMonthStartingAt monthStart: Date, calendar: Calendar) -> Int {
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return 0 }
        return attributedBreakdown(for: session, calendar: calendar)
            .filter { $0.dayStart >= monthStart && $0.dayStart < monthEnd }
            .reduce(0) { $0 + $1.seeds }
    }

    #if DEBUG
    /// Sanity checks for edge cases (same day, cross midnight, multi-day, 24h boundary).
    static func runSelfChecks() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        func checkPortions(_ label: String, start: Date, end: Date, duration: Int, expectedSum: Int) {
            let p = dayPortions(start: start, end: end, durationSeconds: duration, calendar: cal)
            let sum = p.reduce(0) { $0 + $1.seconds }
            if sum != expectedSum {
                print("[SessionDayAttribution] Self-check failed: \(label) sum=\(sum) expected=\(expectedSum)")
            }
        }

        var c = DateComponents()
        c.timeZone = cal.timeZone
        c.year = 2024
        c.month = 1
        c.day = 1
        c.hour = 10
        c.minute = 0
        let d1 = cal.date(from: c)!
        c.hour = 15
        let d1end = cal.date(from: c)!
        checkPortions("same-day", start: d1, end: d1end, duration: 5 * 3600, expectedSum: 5 * 3600)

        c.day = 1
        c.hour = 22
        let crossStart = cal.date(from: c)!
        c.day = 2
        c.hour = 2
        let crossEnd = cal.date(from: c)!
        checkPortions("cross-midnight", start: crossStart, end: crossEnd, duration: 4 * 3600, expectedSum: 4 * 3600)

        c.day = 5
        c.hour = 12
        let longStart = cal.date(from: c)!
        c.day = 7
        c.hour = 12
        let longEnd = cal.date(from: c)!
        checkPortions("48h wall 48h duration", start: longStart, end: longEnd, duration: 48 * 3600, expectedSum: 48 * 3600)

        c.day = 5
        c.hour = 0
        let exactStart = cal.date(from: c)!
        c.day = 6
        c.hour = 0
        let exactEnd = cal.date(from: c)!
        checkPortions("exact 24h", start: exactStart, end: exactEnd, duration: 24 * 3600, expectedSum: 24 * 3600)
    }
    #endif
}
