import Foundation

enum LikeFeedback {
    private static let endpoint = URL(string: "https://script.google.com/macros/s/AKfycbx_I_pCf8hm26KiCJmyxIc_o4jv_tAReusYab3Gg14syMFiiyCBDgfWyzCid0JA_Xp1Ng/exec")!

    private struct Response: Decodable { let ok: Bool }

    static func send() async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"type":"like"}"#.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              data.count < 1_000,
              (try? JSONDecoder().decode(Response.self, from: data))?.ok == true else {
            throw URLError(.badServerResponse)
        }
    }
}
