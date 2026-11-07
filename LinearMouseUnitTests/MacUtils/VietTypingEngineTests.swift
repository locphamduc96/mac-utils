// MIT License
// Copyright (c) 2026 MacUtils

@testable import LinearMouse
import XCTest

final class VietTypingEngineTests: XCTestCase {
    private func assertTyping(
        _ cases: [(String, String)],
        settings: VietTypingSettings = VietTypingSettings(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (keys, expected) in cases {
            XCTAssertEqual(
                VietTypingTestSupport.type(keys, settings: settings),
                expected,
                "keys: \(keys)",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Telex

    func testTelexWords() {
        assertTyping([
            ("tieengs vieetj", "tiếng việt"),
            ("Tooi ddang gox tieengs Vieetj", "Tôi đang gõ tiếng Việt"),
            ("dduowngf", "đường"),
            ("nguwowif", "người"),
            ("nguwoif", "người"),
            ("nguoiwf", "người"),
            ("muoons", "muốn"),
            ("ruowuj", "rượu"),
            ("chuwa", "chưa"),
            ("cuar", "của"),
            ("hieenj taij", "hiện tại"),
            ("ddeer", "để"),
            ("laij", "lại"),
            ("ngoaif", "ngoài"),
            ("nguyeenx", "nguyễn"),
            ("chuyeenj", "chuyện"),
            ("khuyur", "khuỷu"),
            ("caanf", "cần"),
            ("awn", "ăn"),
            ("hoawcj", "hoặc"),
            ("xooong", "xoong"),
            ("tw", "tư"),
            ("w", "ư"),
            ("nhw", "như")
        ])
    }

    func testQuAndGi() {
        assertTyping([
            ("quas", "quá"),
            ("quoocs", "quốc"),
            ("quyeenf", "quyền"),
            ("quaan", "quân"),
            ("gias", "giá"),
            ("giuwax", "giữa"),
            ("gif", "gì"),
            ("gieengs", "giếng"),
            ("giuwowngf", "giường")
        ])
    }

    func testModifiersCanComeLater() {
        assertTyping([
            ("tienges", "tiếng"),
            ("thuongw", "thương"),
            ("duongwf", "dường"),
            ("chuaw", "chưa"),
            ("huuw", "hưu"),
            ("vietej", "việt"),
            ("muonos", "muốn"),
            ("chuooi", "chuôi"),
            ("tiengse", "tiếng"),
            ("doidor", "đổi"),
            ("heset", "hết"),
            ("laf", "là"),
            ("tiesnge", "tiếng"),
            ("doio", "dôi"),
            ("dduowngf", "đường"),
            ("duowngfd", "đường"),
            ("nguoiwf", "người"),
            ("vietje", "việt"),
            ("muonso", "muốn")
        ])
    }

    func testToneStyle() {
        assertTyping([("hoaf", "hòa"), ("thuyr", "thủy"), ("khoer", "khỏe"), ("hoanf", "hoàn")])
        var modern = VietTypingSettings()
        modern.modernStyle = true
        assertTyping([("hoaf", "hoà"), ("thuyr", "thuỷ"), ("khoer", "khoẻ"), ("hoanf", "hoàn")], settings: modern)
    }

    func testToneChangesAndRemoval() {
        assertTyping([
            ("cafs", "cá"),
            ("casz", "ca"),
            ("cass", "cas"),
            ("tesst", "test"),
            ("tesst ", "test "),
            ("aaa", "aa"),
            ("ddd", "dd"),
            ("ww", "w"),
            ("www", "ww")
        ])
    }

    func testUppercase() {
        assertTyping([
            ("VIEETJ", "VIỆT"),
            ("DDUWOWNGF", "ĐƯỜNG"),
            ("Ddi", "Đi"),
            ("Vieetj Nam", "Việt Nam")
        ])
    }

    func testBackspace() {
        assertTyping([
            ("tieengs<", "tiến"),
            ("tieengs<<", "tiế"),
            ("vieetj<t", "việt"),
            ("source<<", "sour"),
            ("banv<f ", "bàn "),
            ("mix⎋<s", "mis"),
            ("as<", "")
        ])
    }

    // MARK: - English

    func testEnglishWordsStayEnglish() {
        assertTyping([
            ("source ", "source "),
            ("text ", "text "),
            ("user ", "user "),
            ("push ", "push "),
            ("return ", "return "),
            ("with ", "with "),
            ("case ", "case "),
            ("expect ", "expect "),
            ("function ", "function "),
            ("is ", "is "),
            ("if ", "if "),
            ("was ", "was "),
            ("class ", "class "),
            ("saw ", "saw "),
            ("these ", "these "),
            ("there ", "there "),
            ("queue ", "queue "),
            ("reset ", "reset ")
        ])
    }

    func testEscapeRestoresTypedKeys() {
        assertTyping([("mix⎋", "mix"), ("user⎋", "user"), ("vieetj⎋", "vieetj"), ("message⎋", "message")])
    }

    /// Doubled letters cancel the tone like Unikey; real English words get their keys back when the word ends.
    func testCancelledModifierRestoresEnglishWords() {
        let english: Set = ["message", "issue", "pass", "session", "assert"]
        let engine = VietTypingEngine()
        engine.isEnglishWord = { english.contains($0) }
        let cases = [
            ("message ", "message "), ("issue ", "issue "), ("pass ", "pass "), ("session ", "session "),
            ("assert.", "assert."), ("tesst ", "test "), ("cass ", "cas "), ("message", "mesage"),
            ("messagex< ", "message "), ("messagex<⎋", "message")
        ]
        for (keys, expected) in cases {
            XCTAssertEqual(VietTypingTestSupport.type(keys, engine: engine), expected, "keys: \(keys)")
        }
    }

    func testReturnEndsWord() {
        assertTyping([("user⏎", "user\n"), ("vieetj⏎", "việt\n")])
    }

    func testEnglishRestoreCanBeTurnedOff() {
        var settings = VietTypingSettings()
        settings.restoreEnglish = false
        XCTAssertEqual(VietTypingTestSupport.type("user ", settings: settings), "ủe ")
    }

    // MARK: - VNI and Simple Telex

    func testVNI() {
        var settings = VietTypingSettings()
        settings.method = .vni
        assertTyping([
            ("tie61ng vie65t", "tiếng việt"),
            ("d9u7o7ng2", "đường"),
            ("nguo72i", "người"),
            ("hoa2", "hòa"),
            ("qua1", "quá"),
            ("a8n", "ăn"),
            ("d9i", "đi"),
            ("u7a", "ưa"),
            ("123 ", "123 "),
            ("a1b2", "a1b2")
        ], settings: settings)
    }

    func testSimpleTelex() {
        var settings = VietTypingSettings()
        settings.method = .simpleTelex
        assertTyping([("w", "w"), ("tw", "tw"), ("aw", "ă"), ("uw", "ư"), ("dduwowngf", "đường")], settings: settings)
    }

    // MARK: - Code tables

    func testTCVN3() {
        var settings = VietTypingSettings()
        settings.codeTable = .tcvn3
        assertTyping([
            ("Vieetj Nam", "Vi\u{D6}t Nam"),
            ("dduwowcj", "\u{AE}\u{AD}\u{EE}c"),
            ("DDi", "\u{A7}i")
        ], settings: settings)
    }

    func testVNIWindows() {
        var settings = VietTypingSettings()
        settings.codeTable = .vniWindows
        assertTyping([
            ("Vieetj Nam", "Vie\u{E4}t Nam"),
            ("dduwowcj", "\u{F1}\u{F6}\u{F4}\u{EF}c"),
            ("tieengs", "tie\u{E1}ng"),
            ("Vieetj<<", "Vi")
        ], settings: settings)
    }

    // MARK: - Macros

    func testMacros() {
        var settings = VietTypingSettings()
        settings.macros = ["vn": "Việt Nam", "ko": "không", "pass": "password"]
        assertTyping(
            [("vn ", "Việt Nam "), ("Vn ", "Việt Nam "), ("ko.", "không."), ("vns ", "vns "), ("pass ", "password ")],
            settings: settings
        )
    }

    // MARK: - Every syllable

    /// Every valid syllable with every tone, typed in several key orders, must come out the same.
    func testEverySyllableInSeveralKeyOrders() {
        var checked = 0
        var listFailures: [String] = []
        for syllable in VietTypingTestSupport.allSyllables() {
            let expected = syllable.rendered(modernStyle: false)
            for method in [VietInputMethod.telex, .vni] {
                var settings = VietTypingSettings()
                settings.method = method
                for keys in VietTypingTestSupport.keyOrders(for: syllable, method: method) {
                    checked += 1
                    let output = VietTypingTestSupport.type(keys, settings: settings)
                    if output != expected, listFailures.count < 30 {
                        listFailures.append("\(keys) → \(output), want \(expected)")
                    }
                }
            }
        }
        XCTAssertTrue(listFailures.isEmpty, "\(listFailures.count)+ failures:\n" + listFailures.joined(separator: "\n"))
        XCTAssertGreaterThan(checked, 20_000)
        print("VietTypingEngine: \(checked) key sequences checked")
    }
}

extension VietWord {
    mutating func setToneForTesting(_ tone: VietTone) {
        self = VietWord(letters: letters, tone: tone)
    }

    mutating func dropLastForTesting(_ count: Int) {
        self = VietWord(letters: Array(letters.dropLast(count)), tone: tone)
    }
}
