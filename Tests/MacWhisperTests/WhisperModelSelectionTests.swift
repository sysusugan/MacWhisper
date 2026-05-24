import XCTest
@testable import MacWhisper

final class WhisperModelSelectionTests: XCTestCase {
    func testDefaultModelIsLargeV3Turbo() {
        XCTAssertEqual(WhisperRecognizer.defaultModel, "large-v3_turbo")
    }

    func testMissingSavedModelUsesDefaultModel() {
        XCTAssertEqual(WhisperRecognizer.resolveSelectedModel(savedModel: nil), WhisperRecognizer.defaultModel)
    }

    func testLegacyDistilDefaultMigratesToLargeV3Turbo() {
        XCTAssertEqual(
            WhisperRecognizer.resolveSelectedModel(savedModel: "distil-whisper_distil-large-v3_turbo"),
            WhisperRecognizer.defaultModel
        )
    }

    func testLegacyPrefixedLargeV3TurboMigratesToCurrentLargeV3Turbo() {
        XCTAssertEqual(
            WhisperRecognizer.resolveSelectedModel(savedModel: "openai_whisper-large-v3_turbo"),
            WhisperRecognizer.defaultModel
        )
    }

    func testExplicitNonLegacySavedModelIsPreserved() {
        XCTAssertEqual(
            WhisperRecognizer.resolveSelectedModel(savedModel: "openai_whisper-small.en"),
            "openai_whisper-small.en"
        )
    }

    func testUnavailableSavedModelFallsBackToDefaultWhenAvailable() {
        XCTAssertEqual(
            WhisperRecognizer.resolveSelectedModel(
                savedModel: "large-v2_turbo",
                availableModels: ["large-v3_turbo", "large-v3"]
            ),
            WhisperRecognizer.defaultModel
        )
    }

    func testAvailableSavedModelIsPreserved() {
        XCTAssertEqual(
            WhisperRecognizer.resolveSelectedModel(
                savedModel: "large-v3_947MB",
                availableModels: ["large-v3_turbo", "large-v3_947MB"]
            ),
            "large-v3_947MB"
        )
    }
}
