import Testing
@testable import HearingAidBattery

struct NotesImportParserServiceTests {
    @Test
    func parseCreatesBatteryAndIssueOutputs() {
        let parser = NotesImportParserService()
        let input = """
        July 16, 2023, 9am
        December 12, 2025, 3:26am (wasn't dead but quality low)
        ?did I miss it I don't think so?
        """

        let result = parser.parse(input)

        #expect(result.batteryEvents.count == 1)
        #expect(result.issues.count == 2)
        #expect(result.unknownLines.isEmpty)
        #expect(result.warnings.contains(where: { $0.contains("Missing date/time") }))
    }

    @Test
    func parseMarksUnknownWhenLineCannotBeParsed() {
        let parser = NotesImportParserService()
        let input = "just random words"

        let result = parser.parse(input)

        #expect(result.batteryEvents.isEmpty)
        #expect(result.issues.isEmpty)
        #expect(result.unknownLines == ["just random words"])
        #expect(result.warnings.count == 1)
    }

    @Test
    func parseIsDeterministicForSameInput() {
        let parser = NotesImportParserService()
        let input = "July 24, 2023 8:48pm"

        let first = parser.parse(input)
        let second = parser.parse(input)

        #expect(first.batteryEvents.count == second.batteryEvents.count)
        #expect(first.issues.count == second.issues.count)
        #expect(first.unknownLines == second.unknownLines)
        #expect(first.warnings == second.warnings)
    }
}
