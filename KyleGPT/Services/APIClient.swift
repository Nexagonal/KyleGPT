import Foundation

class APIClient {
    static let shared = APIClient()
    
    private var idToken: String {
        get { UserDefaults.standard.string(forKey: "idToken") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "idToken") }
    }
    
    func authenticatedRequest(url: URL, method: String = "GET") -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        return r
    }
    
    func dataTask(with request: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                self.refreshToken { success in
                    if success {
                        var retryRequest = request
                        retryRequest.setValue("Bearer \(self.idToken)", forHTTPHeaderField: "Authorization")
                        URLSession.shared.dataTask(with: retryRequest, completionHandler: completion).resume()
                    } else {
                        completion(data, response, error)
                    }
                }
            } else {
                completion(data, response, error)
            }
        }.resume()
    }
    
    func fire(request: URLRequest) {
        dataTask(with: request) { _, _, _ in }
    }
    
    private func refreshToken(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(AppConfig.apiKey)") else {
            completion(false); return
        }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&refresh_token=\(UserDefaults.standard.string(forKey: "refreshToken") ?? "")"
        r.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: r) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newToken = json["id_token"] as? String,
                  let newRefresh = json["refresh_token"] as? String else {
                completion(false); return
            }
            self.idToken = newToken
            UserDefaults.standard.set(newRefresh, forKey: "refreshToken")
            completion(true)
        }.resume()
    }
}
