import Foundation

protocol RedirectResolving {
    func redirectTarget(for url: URL) async -> URL?
    func documentBody(for url: URL) async -> String?
}

struct URLSessionRedirectResolver: RedirectResolving {
    init() {}

    func redirectTarget(for url: URL) async -> URL? {
        guard isSafeRemoteRequestURL(url) else {
            return nil
        }

        var request = Self.request(for: url)
        request.httpMethod = "GET"

        let delegate = ManualRedirectDelegate()
        let session = URLSession(
            configuration: Self.privateSessionConfiguration(),
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }

        do {
            let (_, response) = try await session.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (300...399).contains(response.statusCode),
                let location = response.value(forHTTPHeaderField: "Location")
            else {
                return nil
            }
            return URL(string: location, relativeTo: url)?.absoluteURL
        } catch {
            return nil
        }
    }

    func documentBody(for url: URL) async -> String? {
        guard isSafeRemoteRequestURL(url) else {
            return nil
        }

        let request = Self.request(for: url)
        let session = URLSession(configuration: Self.privateSessionConfiguration())
        defer { session.invalidateAndCancel() }

        do {
            let (data, response) = try await session.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode)
            else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private static func privateSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        return configuration
    }

    private static func request(for url: URL) -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 8
        )
        request.httpShouldHandleCookies = false
        request.setValue("Untracker/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }
}

private final class ManualRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}

public struct URLCleaner {
    private let redirectResolver: any RedirectResolving
    private let maxRedirects: Int

    public init() {
        self.init(redirectResolver: URLSessionRedirectResolver())
    }

    init(
        redirectResolver: any RedirectResolving = URLSessionRedirectResolver(),
        maxRedirects: Int = 8
    ) {
        self.redirectResolver = redirectResolver
        self.maxRedirects = maxRedirects
    }

    public func clean(_ text: String, allowsRemoteRequests: Bool = false) async -> String {
        if let standaloneURL = Self.standaloneWebURL(in: text), shouldPreserveSensitiveURL(standaloneURL) {
            return text
        }

        let detections = Self.detectURLs(in: text)
        guard !detections.isEmpty else {
            return text
        }

        let canMakeRemoteRequests = allowsRemoteRequests && Self.allowsRemoteRequests(for: text)
        var output = text
        for detection in detections.reversed() {
            if shouldPreserveSensitiveURL(detection.url) {
                continue
            }

            let cleanedURL = await clean(
                url: detection.url,
                allowsRemoteRequests: canMakeRemoteRequests
            )
            var replacement = cleanedURL.absoluteString
            if !detection.hasScheme {
                replacement = replacement.removingHTTPPrefix()
            }
            if let range = Range(detection.range, in: output) {
                output.replaceSubrange(range, with: replacement)
            }
        }
        return output
    }

    func clean(url: URL, allowsRemoteRequests: Bool = false) async -> URL {
        if shouldPreserveSensitiveURL(url) {
            return url
        }

        var url = url.standardized

        for _ in 0..<maxRedirects {
            let cleanedURL = await cleanOnePass(
                url: url,
                allowsRemoteRequests: allowsRemoteRequests
            ).standardized
            guard cleanedURL.absoluteString != url.absoluteString else {
                return cleanedURL
            }
            url = cleanedURL
        }

        return url
    }

    public static func allowsRemoteRequests(for text: String) -> Bool {
        guard let detectedURL = standaloneURL(in: text) else {
            return false
        }

        return !shouldPreserveSensitiveURL(detectedURL.url) && isSafeRemoteRequestURL(detectedURL.url)
    }

    private static func standaloneWebURL(in text: String) -> URL? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedText.isEmpty,
            let url = URL(string: trimmedText),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host != nil
        else {
            return nil
        }

        return url
    }

    private static func standaloneURL(in text: String) -> DetectedURL? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        let detections = Self.detectURLs(in: text)
        guard detections.count == 1 else {
            return nil
        }

        let detectedText = (text as NSString).substring(with: detections[0].range)
        guard detectedText == trimmedText else {
            return nil
        }
        return detections[0]
    }

    private func cleanOnePass(url: URL, allowsRemoteRequests: Bool) async -> URL {
        var url = url.standardized

        if let redirected = commonRedirectionTarget(for: url) {
            url = redirected.standardized
        }

        if shouldPreserveSensitiveURL(url) {
            return url
        }

        url = removingKnownTrackingParameters(from: url)
        if allowsRemoteRequests {
            url = await expandedCommonShortLink(from: url)
        }
        if shouldPreserveSensitiveURL(url) {
            return url
        }
        url = removingKnownTrackingParameters(from: url)

        if matches(url, hostPattern: ".+\\.amazon\\.(ae|ca|cn|co\\.jp|co\\.uk|com|com\\.au|com\\.be|com\\.br|com\\.mx|com\\.tr|de|eg|es|fr|in|it|nl|pl|sa|se|sg)") {
            url = settingEncodedQuery(nil, in: url)
            url = replacingEncodedPath(in: url) { path in
                path.replacingFullRegex("(?<=/)ref=.+$", with: "")
            }
        }

        if matches(url, hostPattern: ".+\\.bilibili\\.com") {
            url = retainingQueryParameters(
                in: url,
                keyPattern: "business_id|business_type|itemsId|lottery_id|p|start_progress|t"
            )
            url = removingQueryParameters(from: url, keyPattern: "p", valuePattern: "1")
        }

        if matches(url, hostPattern: ".+\\.douban\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: ".+\\.(douyin|iesdouyin)\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: "www\\.google\\.com", encodedPathPattern: "/search") {
            url = retainingQueryParameters(in: url, keyPattern: "q|tbm")
        }

        if matches(url, hostPattern: "www\\.instagram\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: ".+\\.jd\\.com") {
            url = retainingQueryParameters(in: url, keyPattern: "id|shopId|skuIds|suitId|wareId")
        }

        if matches(url, hostPattern: "(.+\\.)?m\\.chenzhongtech\\.com|m\\.gifshow\\.com|.+\\.kuaishou\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: "y\\.music\\.163\\.com") {
            url = retainingQueryParameters(in: url, keyPattern: "id")
        }

        if matches(url, hostPattern: "www\\.netflix\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: "www\\.pinterest\\.com") {
            url = settingEncodedQuery(nil, in: url)
            url = replacingEncodedPath(in: url) { path in
                path.replacingFullRegex("(?<=/)sent/?$", with: "")
            }
        }

        if matches(url, hostPattern: "(.+\\.)?reddit\\.com") {
            url = retainingQueryParameters(in: url, keyPattern: "context")
        }

        if matches(url, hostPattern: ".+\\.xiaohongshu\\.com") {
            url = retainingQueryParameters(in: url, keyPattern: "xsec_token")
        }

        if matches(url, hostPattern: ".+\\.smzdm\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: "(open\\.)?spotify\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(
            url,
            hostPattern: "(.+\\.stackexchange|askubuntu|serverfault|stackoverflow|superuser)\\.com",
            encodedPathPattern: "/[aq]/[0-9]+/[0-9]+/?"
        ) {
            url = replacingEncodedPath(in: url) { path in
                path.replacingFullRegex("/[0-9]+/?$", with: "")
            }
        }

        if matches(url, hostPattern: ".+\\.(taobao|tmall)\\.com") {
            url = retainingQueryParameters(in: url, keyPattern: "id")
        }

        if matches(url, hostPattern: "www\\.threads\\.com") {
            url = removingQueryParameters(from: url, keyPattern: "slof|xmt")
        }

        if matches(url, hostPattern: ".+\\.tiktok\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: "(twitter|x)\\.com") {
            url = settingEncodedQuery(nil, in: url)
        }

        if matches(url, hostPattern: "youtu\\.be|((music|www)\\.)?youtube\\.com") {
            url = retainingQueryParameters(in: url, keyPattern: "index|list|t|v")
        }

        return url
    }
}

private extension URLCleaner {
    struct DetectedURL {
        let range: NSRange
        let hasScheme: Bool
        let url: URL
    }

    static func detectURLs(in text: String) -> [DetectedURL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        return detector.matches(in: text, range: fullRange).compactMap { match in
            guard match.resultType == .link else {
                return nil
            }

            let rawValue = nsText.substring(with: match.range)
            let lowercasedRawValue = rawValue.lowercased()
            guard
                !lowercasedRawValue.hasPrefix("rtsp://"),
                !lowercasedRawValue.hasPrefix("ftp://")
            else {
                return nil
            }

            let hasScheme = lowercasedRawValue.hasPrefix("http://") || lowercasedRawValue.hasPrefix("https://")
            let candidate = hasScheme ? rawValue : "http://\(rawValue)"
            guard
                let url = URL(string: candidate),
                let scheme = url.scheme?.lowercased(),
                scheme == "http" || scheme == "https",
                url.host != nil
            else {
                return nil
            }
            return DetectedURL(range: match.range, hasScheme: hasScheme, url: url)
        }
    }

    func commonRedirectionTarget(for url: URL) -> URL? {
        if matches(
            url,
            hostPattern: "www\\.douban\\.com",
            encodedPathPattern: "/link2/",
            encodedQueryPattern: ".*\\burl=.+"
        ) {
            return decodedQueryValue(named: "url", in: url).flatMap { URL(string: $0, relativeTo: url)?.absoluteURL }
        }

        if matches(
            url,
            hostPattern: "search\\.app",
            encodedPathPattern: "/",
            encodedQueryPattern: ".*\\blink=.+"
        ) {
            return decodedQueryValue(named: "link", in: url).flatMap { URL(string: $0, relativeTo: url)?.absoluteURL }
        }

        if matches(
            url,
            hostPattern: "link\\.zhihu\\.com",
            encodedPathPattern: "/",
            encodedQueryPattern: ".*\\btarget=.+"
        ) {
            return decodedQueryValue(named: "target", in: url).flatMap { URL(string: $0, relativeTo: url)?.absoluteURL }
        }

        return nil
    }

    func expandedCommonShortLink(from url: URL) async -> URL {
        var url = url
        for _ in 0..<maxRedirects {
            if isCommonShortLink(url) {
                guard isSafeRemoteRequestURL(url) else {
                    break
                }
                guard let redirectedURL = await redirectResolver.redirectTarget(for: url) else {
                    break
                }
                let standardizedURL = redirectedURL.standardized
                guard standardizedURL != url else {
                    break
                }
                url = standardizedURL
                continue
            }

            if matches(url, hostPattern: "([cm]\\.)?tb\\.cn") {
                guard isSafeRemoteRequestURL(url) else {
                    break
                }
                guard
                    let body = await redirectResolver.documentBody(for: url),
                    let target = taobaoRedirectTarget(in: body, relativeTo: url)
                else {
                    break
                }
                let standardizedURL = target.standardized
                guard standardizedURL != url else {
                    break
                }
                url = standardizedURL
                continue
            }

            break
        }
        return url
    }

    func isCommonShortLink(_ url: URL) -> Bool {
        matches(
            url,
            hostPattern: "163cn\\.tv|a\\.co|amzn\\.(asia|eu|to)|b23\\.tv|bili2233\\.cn|v\\.douyin\\.com|dwz\\.cn|u\\.jd\\.com|v\\.kuaishou\\.com|pin\\.it|share\\.google(\\.com)?|t\\.cn|vm\\.tiktok\\.com|url\\.cn|xhslink\\.com"
        ) ||
            matches(url, hostPattern: "m\\.gifshow\\.com", encodedPathPattern: "/s/.+") ||
            matches(url, hostPattern: "www\\.google\\.com", encodedPathPattern: "/share\\.google") ||
            matches(url, hostPattern: "www\\.instagram\\.com", encodedPathPattern: "/share/reel/.+") ||
            matches(url, hostPattern: "api\\.pinterest\\.com", encodedPathPattern: "/url_shortener/.+") ||
            matches(url, hostPattern: "www\\.reddit\\.com", encodedPathPattern: "/r/[^/]+/s/.+") ||
            matches(url, hostPattern: "search\\.app", encodedPathPattern: "/.+")
    }

    func taobaoRedirectTarget(in body: String, relativeTo url: URL) -> URL? {
        guard
            let range = body.range(
                of: #"var url = '([^']+)';"#,
                options: [.regularExpression]
            )
        else {
            return nil
        }

        let statement = String(body[range])
        guard
            let start = statement.range(of: "'")?.upperBound,
            let end = statement[start...].range(of: "'")?.lowerBound
        else {
            return nil
        }
        return URL(string: String(statement[start..<end]), relativeTo: url)?.absoluteURL
    }
}

private func matches(
    _ url: URL,
    hostPattern: String? = nil,
    encodedPathPattern: String? = nil,
    encodedQueryPattern: String? = nil,
    encodedFragmentPattern: String? = nil
) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return false
    }

    if let hostPattern {
        guard let host = components.host, host.matchesFullRegex(hostPattern) else {
            return false
        }
    }

    if let encodedPathPattern, !components.percentEncodedPath.matchesFullRegex(encodedPathPattern) {
        return false
    }

    if let encodedQueryPattern, let encodedQuery = components.percentEncodedQuery {
        guard encodedQuery.matchesFullRegex(encodedQueryPattern) else {
            return false
        }
    }

    if let encodedFragmentPattern, let encodedFragment = components.percentEncodedFragment {
        guard encodedFragment.matchesFullRegex(encodedFragmentPattern) else {
            return false
        }
    }

    return true
}

private func isSafeRemoteRequestURL(_ url: URL) -> Bool {
    guard
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let scheme = components.scheme?.lowercased(),
        scheme == "https",
        components.host != nil,
        components.user == nil,
        components.password == nil,
        !shouldPreserveSensitiveURL(url)
    else {
        return false
    }

    return true
}

private func shouldPreserveSensitiveURL(_ url: URL) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return false
    }

    if components.user != nil || components.password != nil {
        return true
    }

    let items = decodedQueryItems(from: components.percentEncodedQuery)
    guard !items.isEmpty else {
        return false
    }

    return items.contains { isSensitiveQueryItem($0) }
}

private func isSensitiveQueryItem(_ item: (name: String, value: String)) -> Bool {
    let normalizedName = item.name
        .replacingOccurrences(of: "-", with: "_")
        .lowercased()

    if normalizedName.matchesFullRegex(sensitiveQueryNamePattern) {
        return true
    }

    if normalizedName.matchesFullRegex(callbackQueryNamePattern) {
        return true
    }

    if looksLikeLocalCallbackURL(item.value) {
        return true
    }

    return false
}

private let sensitiveQueryNamePattern = [
    "access_token",
    "auth(_?token)?",
    "challenge",
    "code",
    "id_token",
    "jwt",
    "nonce",
    "refresh_token",
    "saml(response|request)",
    "session(_?id)?",
    "state",
    "ticket",
    "token"
].joined(separator: "|")

private let callbackQueryNamePattern = [
    "callback(_?url|_?uri)?",
    "continue",
    "flow",
    "next",
    "redirect(_?url|_?uri)?",
    "return(_?to|_?url|_?uri|https)?"
].joined(separator: "|")

private func looksLikeLocalCallbackURL(_ value: String) -> Bool {
    guard
        let callbackURL = URL(string: value),
        let scheme = callbackURL.scheme?.lowercased(),
        scheme == "http" || scheme == "https",
        let host = callbackURL.host?.lowercased()
    else {
        return false
    }

    return host == "localhost" ||
        host.hasSuffix(".localhost") ||
        host == "127.0.0.1" ||
        host == "::1" ||
        host.hasPrefix("127.")
}

private func settingEncodedQuery(_ encodedQuery: String?, in url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url
    }
    components.percentEncodedQuery = encodedQuery
    return components.url ?? url
}

private func replacingEncodedPath(in url: URL, transform: (String) -> String) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url
    }
    components.percentEncodedPath = transform(components.percentEncodedPath)
    return components.url ?? url
}

private func removingKnownTrackingParameters(from url: URL) -> URL {
    var url = removingQueryParameters(from: url, keyPattern: "[isu]tm_.*|ref")
    url = removingQueryParameters(from: url, keyPattern: "(fb|g|tt|wicked|y)cl(id|source|src)|[gw]braid")
    return removingQueryParameters(
        from: url,
        keyPattern: [
            "_hs(enc|mi)",
            "dclid",
            "igsh(id)?",
            "mc_(cid|eid)",
            "mkt_tok",
            "msclkid",
            "oly_(anon|enc)_id",
            "pk_(campaign|kwd|medium|source)",
            "piwik_(campaign|kwd)",
            "shem",
            "vero_id",
            "wt\\.mc_id"
        ].joined(separator: "|")
    )
}

private func removingQueryParameters(
    from url: URL,
    keyPattern: String? = nil,
    valuePattern: String? = nil
) -> URL {
    filteredQueryParameters(in: url, keyPattern: keyPattern, valuePattern: valuePattern, keepingMatches: false)
}

private func retainingQueryParameters(
    in url: URL,
    keyPattern: String? = nil,
    valuePattern: String? = nil
) -> URL {
    filteredQueryParameters(in: url, keyPattern: keyPattern, valuePattern: valuePattern, keepingMatches: true)
}

private func filteredQueryParameters(
    in url: URL,
    keyPattern: String?,
    valuePattern: String?,
    keepingMatches: Bool
) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url
    }

    let items = decodedQueryItems(from: components.percentEncodedQuery)
    guard !items.isEmpty else {
        return url
    }

    let filteredItems = items.filter { item in
        let keyMatches = keyPattern.map { item.name.matchesFullRegex($0) } ?? true
        let valueMatches = valuePattern.map { item.value.matchesFullRegex($0) } ?? true
        let matches = keyMatches && valueMatches
        return keepingMatches ? matches : !matches
    }

    components.queryItems = filteredItems.isEmpty
        ? nil
        : filteredItems.map { URLQueryItem(name: $0.name, value: $0.value) }
    return components.url ?? url
}

private func decodedQueryValue(named name: String, in url: URL) -> String? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }
    return decodedQueryItems(from: components.percentEncodedQuery)
        .first { $0.name == name }?
        .value
}

private func decodedQueryItems(from percentEncodedQuery: String?) -> [(name: String, value: String)] {
    guard let percentEncodedQuery, !percentEncodedQuery.isEmpty else {
        return []
    }

    return percentEncodedQuery.split(separator: "&", omittingEmptySubsequences: false).map { pair in
        let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let name = String(parts[0]).removingPercentEncoding ?? String(parts[0])
        let value: String
        if parts.count > 1 {
            value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        } else {
            value = ""
        }
        return (name, value)
    }
}

private extension String {
    func matchesFullRegex(_ pattern: String) -> Bool {
        range(
            of: "^(?:\(pattern))$",
            options: [.caseInsensitive, .regularExpression]
        ) != nil
    }

    func replacingFullRegex(_ pattern: String, with replacement: String) -> String {
        replacingOccurrences(
            of: pattern,
            with: replacement,
            options: [.caseInsensitive, .regularExpression]
        )
    }

    func removingHTTPPrefix() -> String {
        hasPrefix("http://") ? String(dropFirst("http://".count)) : self
    }
}
