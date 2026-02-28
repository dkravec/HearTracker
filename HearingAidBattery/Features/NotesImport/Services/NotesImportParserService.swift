import Foundation

struct NotesImportParserService {
    private static let issueKeywords: [String] = [
        "issue", "problem", "not working", "quality", "static", "noise", "low", "did i miss"
    ]

    func parse(_ text: String) -> NotesImportParseResult {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { sanitizeLine(String($0)) }
            .filter { !$0.isEmpty }

        var batteryEvents: [NotesImportParsedItem] = []
        var issues: [NotesImportParsedItem] = []
        var unknownLines: [String] = []
        var warnings: [String] = []

        for line in lines {
            let extraction = extractDateAndText(from: line)
            let lowered = line.lowercased()
            let looksIssue = line.hasPrefix("?") || Self.issueKeywords.contains(where: { lowered.contains($0) })

            if let timestamp = extraction.date {
                let text = extraction.trailingText
                if looksIssue {
                    issues.append(
                        NotesImportParsedItem(
                            kind: .issue,
                            originalLine: line,
                            timestamp: timestamp,
                            text: text,
                            timestampInferred: extraction.usedDateOnly
                        )
                    )
                } else {
                    batteryEvents.append(
                        NotesImportParsedItem(
                            kind: .battery,
                            originalLine: line,
                            timestamp: timestamp,
                            text: text,
                            timestampInferred: extraction.usedDateOnly
                        )
                    )
                }

                if extraction.usedDateOnly {
                    warnings.append("Missing time in line: \(line)")
                }
            } else if looksIssue {
                issues.append(
                    NotesImportParsedItem(
                        kind: .issue,
                        originalLine: line,
                        timestamp: nil,
                        text: nil,
                        timestampInferred: false
                    )
                )
                warnings.append("Missing date/time in line: \(line)")
            } else {
                unknownLines.append(line)
                warnings.append("Could not parse line: \(line)")
            }
        }

        return NotesImportParseResult(
            batteryEvents: batteryEvents,
            issues: issues,
            unknownLines: unknownLines,
            warnings: warnings
        )
    }

    private func sanitizeLine(_ line: String) -> String {
        var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("- ") {
            value.removeFirst(2)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractDateAndText(from line: String) -> (date: Date?, trailingText: String?, usedDateOnly: Bool) {
        let normalized = line.replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")

        let patterns: [(format: String, hasTime: Bool)] = [
            ("MMMM d, yyyy, h:mma", true),
            ("MMMM d, yyyy, h:mm a", true),
            ("MMMM d, yyyy h:mma", true),
            ("MMMM d, yyyy h:mm a", true),
            ("MMMM d, yyyy, h a", true),
            ("MMMM d, yyyy h a", true),
            ("MMMM d, yyyy, H:mm", true),
            ("MMMM d, yyyy H:mm", true),
            ("MMMM d, yyyy", false)
        ]

        for candidate in candidateDatePrefixes(from: normalized) {
            for pattern in patterns {
                if let date = parseDate(candidate, format: pattern.format) {
                    let trailing = trailingText(from: normalized, matchedPrefix: candidate)
                    return (date, trailing, pattern.hasTime == false)
                }
            }
        }

        return (nil, nil, false)
    }

    private func parseDate(_ value: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = format
        return formatter.date(from: value)
    }

    private func candidateDatePrefixes(from line: String) -> [String] {
        let parts = line.split(separator: ",", omittingEmptySubsequences: false)
        var candidates: [String] = []

        if parts.count >= 2 {
            candidates.append(parts.prefix(2).joined(separator: ",").trimmingCharacters(in: .whitespaces))
        }
        if parts.count >= 3 {
            candidates.append(parts.prefix(3).joined(separator: ",").trimmingCharacters(in: .whitespaces))
        }
        if parts.count >= 4 {
            candidates.append(parts.prefix(4).joined(separator: ",").trimmingCharacters(in: .whitespaces))
        }

        // Also support "July 24, 2023 8:48pm" (no comma before time).
        let words = line.split(separator: " ")
        if words.count >= 4 {
            candidates.append(words.prefix(4).joined(separator: " ").trimmingCharacters(in: .whitespaces))
        }

        return Array(Set(candidates)).sorted { $0.count > $1.count }
    }

    private func trailingText(from line: String, matchedPrefix: String) -> String? {
        guard let range = line.range(of: matchedPrefix) else { return nil }
        let trailingRaw = line[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trailingRaw.isEmpty else { return nil }

        if trailingRaw.hasPrefix("(") && trailingRaw.hasSuffix(")") {
            let cleaned = trailingRaw.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }

        return trailingRaw
    }
}
