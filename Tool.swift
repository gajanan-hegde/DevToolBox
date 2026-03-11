import Foundation

enum Tool: String, CaseIterable, Identifiable {
    case jwtDecoder = "JWT Decoder"
    case jsonEditor = "JSON Editor"
    case jsonDiff = "JSON Diff"
    case yamlEditor = "YAML Editor"
    case jsonYamlConverter = "JSON <> YAML Converter"
    case urlEncoder = "URL Encoder/Decoder"
    case base64Encoder = "Base64 Encoder/Decoder"

    var id: String { self.rawValue }
    var name: String { self.rawValue }
}
