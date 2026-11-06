// MIT License
// Copyright (c) 2026 MacUtils

@testable import LinearMouse
import XCTest

final class VietEnglishRestoreTests: XCTestCase {
    /// Common English and programming words typed in Telex with "restore English" on.
    private static let listWords = """
    the be to of and a in that have it for not on with he as you do at this but his by from they we say her she or \
    an will my one all would there their what so up out if about who get which go me when make can like time no just \
    him know take people into year your good some could them see other than then now look only come its over think \
    also back after use two how our work first well way even new want because any these give day most us is was are \
    were been has had did does done code file test build run push pull merge commit branch main master develop \
    release deploy server client request response error warning debug log print return function class struct enum \
    import export default const let var static public private protected final override async await promise \
    callback event handler render component state props hook effect memo store action reducer dispatch query \
    mutation schema model view controller service repository config setting option value key index array list map \
    set string number boolean null undefined true false object type interface generic template source target \
    output input stream buffer cache queue stack tree graph node edge path route router middleware session cookie \
    token auth login logout user admin role permission access account password email phone address name title \
    description content text image video audio font color style theme layout grid flex margin padding border \
    width height size position top bottom left right center align justify display hidden visible opacity \
    transition animation transform scale rotate translate shadow radius background foreground primary secondary \
    success info danger light dark mode screen window frame panel button label field form submit cancel close \
    open save delete update create read write edit copy paste undo redo search filter sort group page next \
    previous first last start stop pause resume reset refresh reload sync async fetch post put patch head \
    options status header body json xml html css script terminal shell command prompt claude review issue \
    ticket sprint feature bug fix hotfix patch version tag package install upgrade dependency library framework \
    module plugin extension tool script data table row column database migration seed backup restore
    """.split { $0 == " " || $0 == "\n" }.map(String.init)

    func testCommonEnglishWordsStayEnglish() {
        var listKept: [String] = []
        var listChanged: [String] = []
        for word in Set(Self.listWords) {
            let output = VietTypingTestSupport.type(word + " ")
            if output == word + " " {
                listKept.append(word)
            } else {
                listChanged.append("\(word) → \(output.trimmingCharacters(in: .whitespaces))")
            }
        }
        let total = listKept.count + listChanged.count
        let ratio = Double(listKept.count) / Double(total)
        print("English restore: \(listKept.count)/\(total) = \(String(format: "%.1f", ratio * 100))% kept")
        print("English restore changed: " + listChanged.sorted().joined(separator: ", "))
        XCTAssertGreaterThan(total, 280)
        XCTAssertGreaterThanOrEqual(ratio, 0.95, listChanged.sorted().joined(separator: ", "))
    }
}
