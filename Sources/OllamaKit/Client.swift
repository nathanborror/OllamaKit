import Foundation

public final class OllamaClient {
    
    let host: URL
    
    public init(host: String = "127.0.0.1:8080") {
        self.host = URL(string: "http://\(host)/api")!
    }
    
    // Generate
    
    public func generate(_ payload: GenerateRequest) async throws -> GenerateResponse {
        var req = makeRequest(path: "generate", method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(GenerateResponse.self, from: data)
    }
    
    public func generateStream(_ payload: GenerateRequest) -> AsyncThrowingStream<GenerateResponse, Error> {
        var body = payload
        body.stream = true
        return makeAsyncRequest(path: "generate", method: "POST", body: body)
    }
    
    // Chats
    
    public func chat(_ payload: ChatRequest) async throws -> ChatResponse {
        var req = makeRequest(path: "chat", method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(ChatResponse.self, from: data)
    }
    
    public func chatStream(_ payload: ChatRequest) -> AsyncThrowingStream<ChatResponse, Error> {
        var body = payload
        body.stream = true
        return makeAsyncRequest(path: "chat", method: "POST", body: body)
    }
    
    // Models
    
    public func modelList() async throws -> ModelListResponse {
        let req = makeRequest(path: "tags", method: "GET")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(ModelListResponse.self, from: data)
    }
    
    public func modelShow(_ payload: ModelShowRequest) async throws -> ModelShowResponse {
        var req = makeRequest(path: "show", method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(ModelShowResponse.self, from: data)
    }
    
    public func modelCopy(_ payload: ModelCopyRequest) async throws {
        var req = makeRequest(path: "copy", method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return
    }
    
    public func modelDelete(_ payload: ModelDeleteRequest) async throws {
        var req = makeRequest(path: "delete", method: "DELETE")
        req.httpBody = try JSONEncoder().encode(payload)
        
        let (_, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return
    }
    
    public func modelPull(_ payload: ModelPullRequest) -> AsyncThrowingStream<ProgressResponse, Error> {
        var body = payload
        body.stream = true
        return makeAsyncRequest(path: "pull", method: "POST", body: body)
    }
    
    public func modelPush(_ payload: ModelPushRequest) -> AsyncThrowingStream<ProgressResponse, Error> {
        var body = payload
        body.stream = true
        return makeAsyncRequest(path: "push", method: "POST", body: body)
    }
    
    // Embeddings
    
    public func embeddings(_ payload: EmbeddingRequest) async throws -> EmbeddingResponse {
        var req = makeRequest(path: "embeddings", method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(EmbeddingResponse.self, from: data)
    }
    
    // Private
    
    private func makeRequest(path: String, method: String) -> URLRequest {
        var req = URLRequest(url: host.appending(path: path))
        req.httpMethod = method
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return req
    }
    
    private func makeAsyncRequest<Body: Codable, Response: Codable>(path: String, method: String, body: Body) -> AsyncThrowingStream<Response, Error> {
        var buffer = Data()
        return AsyncThrowingStream { continuation in
            var req = makeRequest(path: path, method: method)
            req.httpBody = try? JSONEncoder().encode(body)
            
            let task = URLSession.shared.dataTask(with: req) { (data, response, error) in
                if let data = data {
                    buffer.append(data)
                    
                    while let range = buffer.range(of: "\n".data(using: .utf8)!) {
                        let lineData = buffer[..<range.lowerBound]
                        do {
                            let item = try self.decoder.decode(Response.self, from: lineData)
                            continuation.yield(item)
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                        buffer.removeSubrange(..<range.upperBound)
                    }
                }
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                continuation.finish()
            }
            task.resume()
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    private var decoder: JSONDecoder {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }
}