import XCTest

/// End-to-end checks of the main flows, driving the real app.
final class FitDropUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(demo: Bool, tab: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-FitDropReset", "YES"]
        if demo { app.launchArguments += ["-FitDropDemo", "YES"] }
        if let tab { app.launchArguments += ["-FitDropTab", tab] }
        app.launch()
    }

    /// Decimal keypads have no return key, so the app adds a Done button above the keyboard.
    private func dismissKeyboard() {
        let done = app.toolbars.buttons["Done"]
        if done.waitForExistence(timeout: 2) { done.tap() }
    }

    private var continueButton: XCUIElement { app.buttons["onboardingContinue"] }

    private func tapTab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    func testOnboardingReachesToday() {
        launch(demo: false)

        let name = app.textFields["e.g. Alex"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Sam")
        continueButton.tap()

        XCTAssertTrue(app.staticTexts["About You"].waitForExistence(timeout: 3))
        app.buttons["Male"].tap()
        let height = app.textFields["0.0"]
        height.tap()
        height.typeText("180")
        dismissKeyboard()
        continueButton.tap()

        let weightTitle = app.staticTexts["Your Weight"]
        if !weightTitle.waitForExistence(timeout: 3) { print("HIERARCHY:\n\(app.debugDescription)") }
        XCTAssertTrue(weightTitle.exists)
        let weights = app.textFields.matching(NSPredicate(format: "placeholderValue == '0.0'"))
        weights.element(boundBy: 0).tap()
        weights.element(boundBy: 0).typeText("92")
        weights.element(boundBy: 1).tap()
        weights.element(boundBy: 1).typeText("82")
        dismissKeyboard()
        continueButton.tap()

        XCTAssertTrue(app.staticTexts["Target Date"].waitForExistence(timeout: 3))
        continueButton.tap()

        XCTAssertTrue(app.staticTexts["Activity Level"].waitForExistence(timeout: 3))
        app.buttons["Let's Go!"].tap()

        // Notification permission prompt comes from SpringBoard
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }

        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Water"].exists)
    }

    func testStartingWorkoutOpensSession() {
        launch(demo: true, tab: "workouts")

        let card = app.buttons.containing(.staticText, identifier: "Easy 5K").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let start = app.buttons["Start Workout"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()

        XCTAssertTrue(app.buttons["Skip Interval"].waitForExistence(timeout: 5), "The workout session should open after tapping Start")
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.staticTexts["PAUSED"].waitForExistence(timeout: 2))
        app.buttons["Resume"].tap()

        app.buttons["End workout"].tap()
        app.buttons["Discard Workout"].tap()
        XCTAssertTrue(app.navigationBars["Workouts"].waitForExistence(timeout: 5))
    }

    func testQuickAddWhileFastingOffersToEndFast() {
        launch(demo: true, tab: "nutrition")

        app.buttons["Add food"].tap()
        XCTAssertTrue(app.alerts["You're Fasting"].waitForExistence(timeout: 3))
        app.alerts.buttons["Log Without Ending"].tap()

        app.buttons["Quick Add"].tap()
        XCTAssertTrue(app.navigationBars["Quick Add"].waitForExistence(timeout: 3))
        let calories = app.textFields["0"].firstMatch
        calories.tap()
        calories.typeText("450")
        app.buttons["Add"].tap()

        // The entry may be in a meal section further down the list
        let row = app.staticTexts["Quick add"]
        for _ in 0..<4 where !row.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(row.exists)
    }

    func testBreakingFastShowsStartCard() {
        launch(demo: true, tab: "fasting")

        let breakButton = app.buttons["Break Fast"]
        XCTAssertTrue(breakButton.waitForExistence(timeout: 5))
        breakButton.tap()
        app.alerts.buttons["Break Fast"].tap()

        XCTAssertTrue(app.staticTexts["Start a Fast"].waitForExistence(timeout: 5))
    }

    func testLoggingWaterAndOpeningSettings() {
        launch(demo: true, tab: "today")

        let addWater = app.buttons["+250 ml"]
        XCTAssertTrue(addWater.waitForExistence(timeout: 5))
        addWater.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '1,75' OR label BEGINSWITH '1.75'")).firstMatch.waitForExistence(timeout: 3))

        app.buttons["Profile and settings"].tap()
        XCTAssertTrue(app.navigationBars["Profile & Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Daily Targets"].exists || app.staticTexts["DAILY TARGETS"].exists)
        app.buttons["Done"].tap()
    }
}
