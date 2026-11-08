import Foundation

enum LikeFeedback {
    private static let endpoint = URL(string: "https://script.google.com/macros/s/AKfycbx_I_pCf8hm26KiCJmyxIc_o4jv_tAReusYab3Gg14syMFiiyCBDgfWyzCid0JA_Xp1Ng/exec")!
    private static let clientIDKey = "likeFeedbackClientID"

    private static var clientID: String {
        if let saved = UserDefaults.standard.string(forKey: clientIDKey), UUID(uuidString: saved) != nil {
            return saved
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: clientIDKey)
        return created
    }

    static func send() async {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["type": "like", "client_id": clientID])
        _ = try? await URLSession.shared.data(for: request)
    }
}
