//
//  A_PomodoroTests.swift
//  A-PomodoroTests
//
//  Created by Audun Steinholm on 21/12/2022.
//

import XCTest

final class A_PomodoroTests: XCTestCase {

    var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yy HH:mm:ss"
        return df
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
    
    func testADay() throws {
        XCTAssertEqual(0, ADay.of(date: Date(timeIntervalSinceReferenceDate: 0)))
        XCTAssertEqual(0, ADay.of(date: Date(timeIntervalSinceReferenceDate: TimeInterval.hour)))
        
        XCTAssertEqual(0, ADay.of(date: dateFormatter.date(from: "01.01.01 00:00:00")!))
        XCTAssertEqual(8040, ADay.of(date: dateFormatter.date(from: "06.01.23 01:02:03")!))
        XCTAssertEqual(8040, ADay.of(date: dateFormatter.date(from: "06.01.23 10:22:00")!))
        XCTAssertEqual(8039, ADay.of(date: dateFormatter.date(from: "05.01.23 23:59:59")!))
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
