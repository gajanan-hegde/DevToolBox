import Foundation

enum Tool: String, CaseIterable, Identifiable, Codable {
    case jwtDecoder = "JWT Decoder"
    case jsonEditor = "JSON Editor"
    case jsonDiff = "JSON Diff"
    case yamlEditor = "YAML Editor"
    case jsonYamlConverter = "JSON <> YAML Converter"
    case urlEncoder = "URL Encoder/Decoder"
    case base64Encoder = "Base64 Encoder/Decoder"
    case epochConverter = "Epoch Converter"

    var id: String { self.rawValue }
    var name: String { self.rawValue }

    var urlParam: String {
        switch self {
        case .jwtDecoder: "jwtDecoder"
        case .jsonEditor: "jsonEditor"
        case .jsonDiff: "jsonDiff"
        case .yamlEditor: "yamlEditor"
        case .jsonYamlConverter: "jsonYamlConverter"
        case .urlEncoder: "urlEncoder"
        case .base64Encoder: "base64Encoder"
        case .epochConverter: "epochConverter"
        }
    }

    static func fromURLParam(_ param: String) -> Tool? {
        allCases.first { $0.urlParam == param }
    }

    var icon: String {
        switch self {
        case .jwtDecoder: "key.fill"
        case .jsonEditor: "curlybraces"
        case .jsonDiff: "arrow.left.arrow.right"
        case .yamlEditor: "doc.plaintext"
        case .jsonYamlConverter: "arrow.triangle.2.circlepath"
        case .urlEncoder: "link"
        case .base64Encoder: "number"
        case .epochConverter: "clock"
        }
    }
}
