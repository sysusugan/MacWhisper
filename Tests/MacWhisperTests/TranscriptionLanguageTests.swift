import XCTest
@testable import MacWhisper

final class TranscriptionLanguageTests: XCTestCase {
    @MainActor
    func testRecognizerDefaultsToChineseForNewUsers() {
        let recognizer = WhisperRecognizer()

        XCTAssertEqual(recognizer.preferredLanguage, .chinese)
    }

    func testAutoLanguageUsesDetectionWithoutPinnedCode() {
        let options = WhisperRecognizer.makeDecodingOptions(language: .auto, lockedLanguageCode: nil, clipStart: 0)

        XCTAssertNil(options.language)
        XCTAssertTrue(options.detectLanguage)
        XCTAssertFalse(options.usePrefillPrompt)
    }

    func testAutoLanguageUsesLockedLanguageOnceDetected() {
        let options = WhisperRecognizer.makeDecodingOptions(language: .auto, lockedLanguageCode: "zh", clipStart: 0)

        XCTAssertEqual(options.language, "zh")
        XCTAssertFalse(options.detectLanguage)
        XCTAssertTrue(options.usePrefillPrompt)
    }

    func testChineseLanguagePinsZhWithoutDetection() {
        let options = WhisperRecognizer.makeDecodingOptions(language: .chinese, lockedLanguageCode: nil, clipStart: 0)

        XCTAssertEqual(options.language, "zh")
        XCTAssertFalse(options.detectLanguage)
    }

    func testEnglishLanguagePinsEnWithoutDetection() {
        let options = WhisperRecognizer.makeDecodingOptions(language: .english, lockedLanguageCode: nil, clipStart: 0)

        XCTAssertEqual(options.language, "en")
        XCTAssertFalse(options.detectLanguage)
    }
}
