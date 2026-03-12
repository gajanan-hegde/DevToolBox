import SwiftUI
import Combine

struct URLEncoderView: View {
    @State private var decodedString = "https://example.com/search?q=a b&c=d"
    @State private var encodedString = "https://example.com/search?q=a%20b&c=d"

    private enum Field { case decoded, encoded }
    @State private var activeField: Field = .decoded

    var body: some View {
        HSplitView {
            VStack {
                HStack {
                    Text("Decoded").font(.headline)
                    Spacer()
                    CopyButton(value: decodedString)
                }
                LineNumberedTextEditor(text: $decodedString, focusOnAppear: true)
                    .onChange(of: decodedString) { activeField = .decoded }
            }
            .padding()

            VStack {
                HStack {
                    Text("Encoded").font(.headline)
                    Spacer()
                    CopyButton(value: encodedString)
                }
                LineNumberedTextEditor(text: $encodedString)
                    .onChange(of: encodedString) { activeField = .encoded }
            }
            .padding()
        }
        .navigationTitle("URL Encoder/Decoder")
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
        guard let pending = AppState.shared.pendingInput, pending.tool == .urlEncoder else { return }
        encodedString = pending.content
        activeField = .encoded
        AppState.shared.pendingInput = nil
        convert()
    }

    private func convert() {
        switch activeField {
        case .decoded:
            encodedString = decodedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Invalid input"
        case .encoded:
            decodedString = encodedString.removingPercentEncoding ?? "Invalid encoded string"
        }
    }
}
