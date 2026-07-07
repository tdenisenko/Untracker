import XCTest
@testable import UntrackerCore

final class URLCleanerTests: XCTestCase {
    func testRemovesCommonAnalyticsAndAdParameters() async {
        let cleaner = URLCleaner(redirectResolver: StubRedirectResolver())
        let input = "https://example.com/path?utm_source=news&foo=1&gclid=abc&ref=home"

        let output = await cleaner.clean(input)

        XCTAssertEqual(output, "https://example.com/path?foo=1")
    }

    func testRetainsGoogleSearchParameters() async {
        let cleaner = URLCleaner(redirectResolver: StubRedirectResolver())
        let input = "https://www.google.com/search?q=swift&utm_source=news&tbm=isch&gclid=abc"

        let output = await cleaner.clean(input)

        XCTAssertEqual(output, "https://www.google.com/search?q=swift&tbm=isch")
    }

    func testRetainsYoutubeParametersInTextWithoutScheme() async {
        let cleaner = URLCleaner(redirectResolver: StubRedirectResolver())
        let input = "Watch www.youtube.com/watch?v=abc123&si=tracker&utm_source=share now"

        let output = await cleaner.clean(input)

        XCTAssertEqual(output, "Watch www.youtube.com/watch?v=abc123 now")
    }

    func testExtractsExplicitRedirectBeforeRemovingTrackers() async {
        let cleaner = URLCleaner(redirectResolver: StubRedirectResolver())
        let input = "https://link.zhihu.com/?target=https%3A%2F%2Fexample.com%2Farticle%3Futm_source%3Dnewsletter%26ref%3Dfeed%26id%3D1"

        let output = await cleaner.clean(input)

        XCTAssertEqual(output, "https://example.com/article?id=1")
    }

    func testExpandsShareGoogleRedirects() async {
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google/abc": "https://www.youtube.com/watch?v=video-id&si=tracker&utm_source=share"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "https://share.google/abc",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(output, "https://www.youtube.com/watch?v=video-id")
    }

    func testDoesNotExpandRedirectsWhenRemoteRequestsAreDisabled() async {
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google/abc": "https://example.com/article?id=1"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "Read https://share.google/abc?utm_source=news now",
            allowsRemoteRequests: false
        )

        XCTAssertEqual(output, "Read https://share.google/abc now")
        XCTAssertTrue(resolver.redirectRequests.isEmpty)
        XCTAssertTrue(resolver.documentRequests.isEmpty)
    }

    func testDoesNotExpandRedirectsForMixedTextEvenWhenRemoteRequestsAreAllowed() async {
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google/abc": "https://example.com/article?id=1"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "Read https://share.google/abc?utm_source=news now",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(output, "Read https://share.google/abc now")
        XCTAssertTrue(resolver.redirectRequests.isEmpty)
        XCTAssertTrue(resolver.documentRequests.isEmpty)
    }

    func testDoesNotFetchDocumentsWhenRemoteRequestsAreDisabled() async {
        let resolver = StubRedirectResolver(documents: [
            "https://tb.cn/abc": "var url = 'https://example.com/item?id=1';"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "https://tb.cn/abc?utm_source=news",
            allowsRemoteRequests: false
        )

        XCTAssertEqual(output, "https://tb.cn/abc")
        XCTAssertTrue(resolver.redirectRequests.isEmpty)
        XCTAssertTrue(resolver.documentRequests.isEmpty)
    }

    func testDoesNotExpandHTTPRedirectsEvenWhenRemoteRequestsAreAllowed() async {
        let resolver = StubRedirectResolver(redirects: [
            "http://share.google/abc": "https://example.com/article?id=1"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "http://share.google/abc",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(output, "http://share.google/abc")
        XCTAssertTrue(resolver.redirectRequests.isEmpty)
        XCTAssertTrue(resolver.documentRequests.isEmpty)
    }

    func testDoesNotExpandURLsWithCredentials() async {
        let resolver = StubRedirectResolver(redirects: [
            "https://user:pass@share.google/abc": "https://example.com/article?id=1"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)
        let url = URL(string: "https://user:pass@share.google/abc")!

        let output = await cleaner.clean(url: url, allowsRemoteRequests: true)

        XCTAssertEqual(output.absoluteString, "https://user:pass@share.google/abc")
        XCTAssertTrue(resolver.redirectRequests.isEmpty)
        XCTAssertTrue(resolver.documentRequests.isEmpty)
    }

    func testRemovesTrackingParametersBeforeRemoteRedirectRequest() async {
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google/abc?id=1": "https://example.com/article?utm_source=remote&id=2"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "https://share.google/abc?utm_source=news&id=1&ref=home",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(output, "https://example.com/article?id=2")
        XCTAssertEqual(resolver.redirectRequests, ["https://share.google/abc?id=1"])
        XCTAssertTrue(resolver.documentRequests.isEmpty)
    }

    func testRemoteRequestsAreDisabledByDefault() async {
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google/abc": "https://example.com/article?id=1"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean("https://share.google/abc")

        XCTAssertEqual(output, "https://share.google/abc")
        XCTAssertTrue(resolver.redirectRequests.isEmpty)
        XCTAssertTrue(resolver.documentRequests.isEmpty)
    }

    func testAllowsRemoteRequestsOnlyForStandaloneSafeURL() {
        XCTAssertTrue(URLCleaner.allowsRemoteRequests(for: " https://share.google/abc\n"))
        XCTAssertFalse(URLCleaner.allowsRemoteRequests(for: "Read https://share.google/abc"))
        XCTAssertFalse(URLCleaner.allowsRemoteRequests(for: "https://example.com https://share.google/abc"))
        XCTAssertFalse(URLCleaner.allowsRemoteRequests(for: "share.google/abc"))
        XCTAssertFalse(URLCleaner.allowsRemoteRequests(for: "http://share.google/abc"))
        XCTAssertFalse(URLCleaner.allowsRemoteRequests(for: "https://user:pass@share.google/abc"))
        XCTAssertFalse(URLCleaner.allowsRemoteRequests(for: "not a url"))
    }

    func testURLSessionResolverRejectsUnsafeURLsBeforeNetworking() async {
        let resolver = URLSessionRedirectResolver()

        let httpURL = URL(string: "http://share.google/abc")!
        let credentialsURL = URL(string: "https://user:pass@share.google/abc")!

        let httpRedirect = await resolver.redirectTarget(for: httpURL)
        let httpDocument = await resolver.documentBody(for: httpURL)
        let credentialsRedirect = await resolver.redirectTarget(for: credentialsURL)
        let credentialsDocument = await resolver.documentBody(for: credentialsURL)

        XCTAssertNil(httpRedirect)
        XCTAssertNil(httpDocument)
        XCTAssertNil(credentialsRedirect)
        XCTAssertNil(credentialsDocument)
    }

    func testExpandsShareGoogleComRedirects() async {
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google.com/abc": "https://example.com/story?utm_medium=social&ref=share&id=42"
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "https://share.google.com/abc",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(output, "https://example.com/story?id=42")
    }

    func testReprocessesRedirectTargetsUntilClean() async {
        let redirectedURL = "https://link.zhihu.com/?target=https%3A%2F%2Fexample.com%2Farticle%3Futm_source%3Dnewsletter%26ref%3Dfeed%26id%3D1"
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google.com/redirect": redirectedURL
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "https://share.google.com/redirect",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(output, "https://example.com/article?id=1")
    }

    func testRemovesAdditionalTrackersAfterRedirect() async {
        let redirectedURL = "https://example.com/article?id=1&msclkid=abc&mc_cid=newsletter&_hsenc=token&mkt_tok=token"
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google.com/tracked": redirectedURL
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "https://share.google.com/tracked",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(output, "https://example.com/article?id=1")
    }

    func testRemovesGoogleShemTrackerAfterShareGoogleRedirect() async {
        let googleShareURL = "https://www.google.com/share.google?q=PX66LpRE0Ock9g5r8"
        let destinationURL = "https://www.bloomberght.com/nobel-odullu-ekonomistten-yapay-zeka-uyarisi-3782151?shem=dsdf,sharefoc,agadiscoversdl,,sh/x/discover/m1/4"
        let resolver = StubRedirectResolver(redirects: [
            "https://share.google/PX66LpRE0Ock9g5r8": googleShareURL,
            googleShareURL: destinationURL
        ])
        let cleaner = URLCleaner(redirectResolver: resolver)

        let output = await cleaner.clean(
            "https://share.google/PX66LpRE0Ock9g5r8",
            allowsRemoteRequests: true
        )

        XCTAssertEqual(
            output,
            "https://www.bloomberght.com/nobel-odullu-ekonomistten-yapay-zeka-uyarisi-3782151"
        )
    }
}

private final class StubRedirectResolver: RedirectResolving {
    var redirects: [String: String] = [:]
    var documents: [String: String] = [:]
    private(set) var redirectRequests: [String] = []
    private(set) var documentRequests: [String] = []

    init(
        redirects: [String: String] = [:],
        documents: [String: String] = [:]
    ) {
        self.redirects = redirects
        self.documents = documents
    }

    func redirectTarget(for url: URL) async -> URL? {
        redirectRequests.append(url.absoluteString)
        return redirects[url.absoluteString].flatMap(URL.init(string:))
    }

    func documentBody(for url: URL) async -> String? {
        documentRequests.append(url.absoluteString)
        return documents[url.absoluteString]
    }
}
