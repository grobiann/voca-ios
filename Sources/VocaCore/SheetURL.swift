import Foundation
public enum SheetURL {
    public static func csvURL(from link: String) throws -> URL {
        guard let components = URLComponents(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), components.scheme == "https", components.host == "docs.google.com" else {
            throw ImportFailure.invalid("docs.google.com의 Google Sheets HTTPS 링크를 입력해 주세요.")
        }
        let parts = components.path.split(separator: "/").map(String.init)
        guard parts.count >= 3, parts[0] == "spreadsheets", parts[1] == "d" else { throw ImportFailure.invalid("올바른 스프레드시트 링크가 아닙니다.") }
        let fragment = URLComponents(string: "https://example.com/?" + (components.fragment ?? ""))
        let gid = (components.queryItems ?? []).first { $0.name == "gid" }?.value ?? fragment?.queryItems?.first { $0.name == "gid" }?.value ?? "0"
        var output = URLComponents(); output.scheme = "https"; output.host = "docs.google.com"
        if parts[2] == "e" {
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
