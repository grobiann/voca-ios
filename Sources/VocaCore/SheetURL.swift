import Foundation
public enum SheetURL {
    public struct Tab: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
    }
    public static func manifestURL(from link: String) throws -> URL {
        let csv = try csvURL(from: link, sheetName: "validation")
        var components = URLComponents(url: csv, resolvingAgainstBaseURL: false)!
        components.path = components.path.replacingOccurrences(of: "/gviz/tq", with: "/htmlview")
        components.query = nil
        return components.url!
    }
    // Public htmlview supplies a tab manifest even when the Sheets API requires OAuth.
    // Parse only string data, never evaluate the returned JavaScript. Fail closed if it changes.
    public static func tabs(from data: Data) throws -> [Tab] {
        guard let html = String(data: data, encoding: .utf8) else { throw ImportFailure.invalid("시트 목록을 읽을 수 없습니다.") }
        let pattern = #"items\.push\(\{name:\s*("(?:\\.|[^"\\])*"),\s*pageUrl:\s*"(?:\\.|[^"\\])*",\s*gid:\s*"(-?\d+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let hex = try NSRegularExpression(pattern: #"\\x([0-9a-fA-F]{2})"#)
        let tabs: [Tab] = try regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).map { match in
            let raw = String(html[Range(match.range(at: 1), in: html)!])
            let json = hex.stringByReplacingMatches(in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: #"\\u00$1"#)
            let name = try JSONDecoder().decode(String.self, from: Data(json.utf8))
            return Tab(id: String(html[Range(match.range(at: 2), in: html)!]), name: name)
        }
        guard !tabs.isEmpty else { throw ImportFailure.invalid("시트 목록을 읽을 수 없습니다. 원본 링크와 공개 읽기 설정을 확인해 주세요.") }
        return tabs
    }
    public static func csvURL(from link: String, tab: Tab) throws -> URL {
        let manifest = try manifestURL(from: link)
        var components = URLComponents(url: manifest, resolvingAgainstBaseURL: false)!
        components.path = components.path.replacingOccurrences(of: "/htmlview", with: "/export")
        components.queryItems = [URLQueryItem(name: "format", value: "csv"), URLQueryItem(name: "gid", value: tab.id)]
        return components.url!
    }
    public static func csvURL(from link: String, sheetName: String? = nil) throws -> URL {
        guard let components = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), components.scheme == "https", components.host == "docs.google.com" else {
            throw ImportFailure.invalid("docs.google.com의 Google Sheets HTTPS 링크를 입력해 주세요.")
        }
        let parts = components.path.split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "spreadsheets", parts[1] == "d" else { throw ImportFailure.invalid("올바른 스프레드시트 링크가 아닙니다.") }
        let fragment = URLComponents(string: "https://example.com/?" + (components.fragment ?? ""))
        let gid = (components.queryItems ?? []).first { $0.name == "gid" }?.value ?? fragment?.queryItems?.first { $0.name == "gid" }?.value ?? "0"
        var output = URLComponents(); output.scheme = "https"; output.host = "docs.google.com"
        if let sheetName, !sheetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard parts[2] != "e" else { throw ImportFailure.invalid("시트 이름 선택에는 게시 링크 대신 원본 스프레드시트 링크를 사용해 주세요.") }
            output.path = "/spreadsheets/d/\(parts[2])/gviz/tq"
            output.queryItems = [URLQueryItem(name: "tqx", value: "out:csv"), URLQueryItem(name: "sheet", value: sheetName), URLQueryItem(name: "headers", value: "1")]
        } else if parts[2] == "e" {
            guard parts.count >= 4 else { throw ImportFailure.invalid("게시된 시트 링크를 확인해 주세요.") }
            output.path = "/spreadsheets/d/e/\(parts[3])/pub"
            output.queryItems = [URLQueryItem(name: "output", value: "csv"), URLQueryItem(name: "gid", value: gid), URLQueryItem(name: "single", value: "true")]
        } else {
            output.path = "/spreadsheets/d/\(parts[2])/export"
            output.queryItems = [URLQueryItem(name: "format", value: "csv"), URLQueryItem(name: "gid", value: gid)]
        }
        guard let url = output.url else { throw ImportFailure.invalid("링크를 변환하지 못했습니다.") }
        return url
    }
}
