import Foundation
import Yams

enum ContentDetector {

    /// Returns candidate tools ordered by confidence: JWT → JSON → YAML → URL-encoded → Base64.
    /// Returns an empty array if no detector matches.
    static func detect(_ input: String) -> [Tool] {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return [] }

        var candidates: [Tool] = []

        // 1. JWT - three base64url segments separated by dots
        if matchesJWT(s) { candidates.append(.jwtDecoder) }

        // 2. JSON - parseable object or array
        let json = matchesJSON(s)
        if json { candidates.append(.jsonEditor) }

        // 3. YAML - parseable via Yams, but not already flagged as JSON
        if !json, matchesYAML(s) { candidates.append(.yamlEditor) }

        // 4. URL-encoded - contains at least one %XX sequence
        if matchesURLEncoded(s) { candidates.append(.urlEncoder) }

        // 5. Base64 - charset + length + valid UTF-8 decode
        if matchesBase64(s) { candidates.append(.base64Encoder) }

        return candidates
    }

    // MARK: - Private detectors

    private static func matchesJWT(_ s: String) -> Bool {
        s.range(of: #"^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]*$"#,
                options: .regularExpression) != nil
    }

    private static func matchesJSON(_ s: String) -> Bool {
        guard s.hasPrefix("{") || s.hasPrefix("["),
              let data = s.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else { return false }
        return true
    }

    private static func matchesYAML(_ s: String) -> Bool {
        (try? Yams.load(yaml: s)) != nil
    }

    private static func matchesURLEncoded(_ s: String) -> Bool {
        s.range(of: #"%[0-9A-Fa-f]{2}"#, options: .regularExpression) != nil
    }

    private static func matchesBase64(_ s: String) -> Bool {
        guard s.count > 8, s.count % 4 == 0 else { return false }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        guard s.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        guard let data = Data(base64Encoded: s),
              String(data: data, encoding: .utf8) != nil else { return false }
        return true
    }
}
