//
//  YutubTests.swift
//  YutubTests
//
//  Created by Pau on 7/10/24.
//

import XCTest
@testable import Yutub

final class NavigationAllowlistTests: XCTestCase {

    private func allowed(_ string: String) -> Bool {
        WebViewCoordinator.isAllowed(URL(string: string)!)
    }

    func testYouTubeLoadsInTheApp() {
        XCTAssertTrue(allowed("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        XCTAssertTrue(allowed("https://youtube.com/feed/subscriptions"))
        XCTAssertTrue(allowed("https://m.youtube.com/"))
        XCTAssertTrue(allowed("https://youtu.be/dQw4w9WgXcQ"))
        XCTAssertTrue(allowed("https://accounts.youtube.com/accounts/SetSID"))
    }

    func testGoogleSignInOnCountryDomains() {
        XCTAssertTrue(allowed("https://accounts.google.com/ServiceLogin"))
        XCTAssertTrue(allowed("https://accounts.google.es/accounts/SetSID"))
        XCTAssertTrue(allowed("https://accounts.google.co.uk/accounts/SetSID"))
        XCTAssertTrue(allowed("https://accounts.google.com.br/accounts/SetSID"))
    }

    func testLookAlikesAndOtherSitesDoNot() {
        XCTAssertFalse(allowed("https://notyoutube.com/"))
        XCTAssertFalse(allowed("https://youtube.com.example.net/"))
        XCTAssertFalse(allowed("https://accounts.google.example.net/"))
        XCTAssertFalse(allowed("https://www.google.com/search?q=yutub"))
        XCTAssertFalse(allowed("https://example.com/?u=youtube.com"))
        XCTAssertFalse(allowed("about:blank"))
        XCTAssertFalse(allowed("javascript:alert(1)"))
    }
}
