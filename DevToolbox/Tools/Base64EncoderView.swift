import SwiftUI
import Combine

struct Base64EncoderView: View {
    @State private var decodedString = "Hello, World!"
    @State private var encodedString = "SGVsbG8sIFdvcmxkIQ=="

    private enum Field { case decoded, encoded }
    @State private var activeField: Field = .decoded

    var body: some View {
        HSplitView {
            VStack {
                Text("Decoded (UTF-8)")
                    .font(.headline)
                LineNumberedTextEditor(text: $decodedString, focusOnAppear: true)
                    .onChange(of: decodedString) { activeField = .decoded }
            }
            .padding()

            VStack {
                Text("Encoded (Base64)")
                    .font(.headline)
                LineNumberedTextEditor(text: $encodedString)
                    .onChange(of: encodedString) { activeField = .encoded }
            }
            .padding()
        }
        .navigationTitle("Base64 Encoder/Decoder")
        .onReceive(
            NotificationCenter.default.publisher(for: NSText.didChangeNotification)
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        ) { _ in
            convert()
        }
        .onAppear { applyPendingInput() }
        .onChange(of: AppState.shared.pendingInput) { applyPendingInput() }
    }

    private func applyPendingInput() {
        guard let pending = AppState.shared.pendingInput, pending.tool == .base64Encoder else { return }
        encodedString = pending.content
        activeField = .encoded
        AppState.shared.pendingInput = nil
        convert()
    }

    private func convert() {
        switch activeField {
        case .decoded:
            guard let data = decodedString.data(using: .utf8) else { return }
            encodedString = data.base64EncodedString()
        case .encoded:
            guard let data = Data(base64Encoded: encodedString) else { return }
            decodedString = String(data: data, encoding: .utf8) ?? "Invalid Base64 String"
        }
    }
}
