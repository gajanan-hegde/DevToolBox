import SwiftUI
import Observation

struct PendingInput: Equatable {
    let tool: Tool
    let content: String
}

@Observable
class AppState {
    static let shared = AppState()

    var selectedTool: Tool = .jwtDecoder
    var showingPalette: Bool = false
    var pendingInput: PendingInput? = nil
    var hasLaunched: Bool = false
}
