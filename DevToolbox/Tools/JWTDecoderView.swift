import SwiftUI
import JWTKit

struct JWTDecoderView: View {
    @AppStorage("jwt_decoder_last_token") private var encodedToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    @State private var secret = ""
    @FocusState private var encodedTokenFocused: Bool
    @State private var headerValue: JSONValue = .null
    @State private var payloadValue: JSONValue = .null
    @State private var headerText: String = ""
    @State private var payloadText: String = ""
    @State private var validationStatus = ""
    @State private var isValidating = false
    @State private var viewMode: ViewMode = .tree

    enum ViewMode: String, CaseIterable {
        case tree = "Tree"
        case text = "Text"
    }

    var body: some View {
        HSplitView {
            // ── Left: Encoded token (70%) + Signature verification (30%) ──
            GeometryReader { geo in
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Encoded Token").font(.headline)
                            Spacer()
                            CopyButton(value: encodedToken)
                        }
                        TextEditor(text: $encodedToken)
                            .focused($encodedTokenFocused)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                            .onChange(of: encodedToken) { sanitizeAndDecode() }
                    }
                    .padding()
                    .frame(height: geo.size.height * 0.7)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Signature Verification").font(.headline)
                        TextField("Secret, Public Key, or JWKS URL", text: $secret)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            Button("Validate") { validateToken() }
                                .disabled(isValidating)
                            if isValidating {
                                ProgressView().controlSize(.small)
                            } else if !validationStatus.isEmpty {
                                Text(validationStatus)
                                    .foregroundColor(statusColor)
                                    .font(.callout)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                        }
                    }
                    .padding()
                    .frame(height: geo.size.height * 0.3 - 1)
                }
            }
            .frame(minWidth: 260)

            // ── Right: Header (30%) + Payload (70%) ─────────────
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Picker("", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Header").font(.headline)
                                Spacer()
                                CopyButton(value: headerText)
                            }
                            panel(value: headerValue, text: $headerText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(height: geo.size.height * 0.3)

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Payload").font(.headline)
                                Spacer()
                                CopyButton(value: payloadText)
                            }
                            panel(value: payloadValue, text: $payloadText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(height: geo.size.height * 0.7 - 1)
                    }
                }
            }
            .frame(minWidth: 260)
        }
        .navigationTitle("JWT Decoder")
        .onAppear {
            applyPendingInput()
            decodeToken()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                encodedTokenFocused = true
            }
        }
        .onChange(of: AppState.shared.pendingInput) { applyPendingInput() }
    }

    private var statusColor: Color {
        switch validationStatus {
        case "Signature Verified": return .green
        case let s where s.hasPrefix("Fetching"): return .secondary
        default: return .red
        }
    }

    private static let jwtTimestampKeys: Set<String> = ["iat", "exp", "nbf"]

    @ViewBuilder
    private func panel(value: JSONValue, text: Binding<String>) -> some View {
        switch viewMode {
        case .tree:
            JSONTreeView(value: value, timestampKeys: Self.jwtTimestampKeys)
        case .text:
            LineNumberedTextEditor(text: text, isEditable: false, timestampKeys: Self.jwtTimestampKeys)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
        }
    }

    private func applyPendingInput() {
        guard let pending = AppState.shared.pendingInput, pending.tool == .jwtDecoder else { return }
        encodedToken = pending.content
        AppState.shared.pendingInput = nil
    }

    // MARK: - Validation

    private func validateToken() {
        guard !secret.isEmpty else {
            validationStatus = "Secret cannot be empty"
            return
        }
        let input = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidating = true
        validationStatus = ""

        Task { @MainActor in
            defer { isValidating = false }

            if let url = URL(string: input), (url.scheme == "https" || url.scheme == "http"), url.host != nil {
                // JWKS endpoint
                validationStatus = "Fetching keys…"
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        validationStatus = "HTTP \(http.statusCode) fetching JWKS"
                        return
                    }
                    let jwks = try JSONDecoder().decode(JWKS.self, from: data)
                    let keys = JWTKeyCollection()
                    var loaded = 0
                    for jwk in jwks.keys {
                        if (try? await keys.add(jwk: jwk)) != nil { loaded += 1 }
                    }
                    guard loaded > 0 else {
                        validationStatus = "No usable keys in JWKS response"
                        return
                    }
                    _ = try await keys.verify(encodedToken, as: Claims.self)
                    validationStatus = "Signature Verified"
                } catch {
                    validationStatus = friendlyValidationError(error)
                }
            } else {
                // HMAC secret
                do {
                    let keys = JWTKeyCollection()
                    await keys.add(hmac: HMACKey(from: input), digestAlgorithm: .sha256)
                    _ = try await keys.verify(encodedToken, as: Claims.self)
                    validationStatus = "Signature Verified"
                } catch {
                    validationStatus = friendlyValidationError(error)
                }
            }
        }
    }

    private func friendlyValidationError(_ error: Error) -> String {
        if let jwt = error as? JWTError {
            switch jwt.errorType {
            case .unknownKID:
                let kid = jwt.kid?.string ?? "required key"
                return "Signing key '\(kid)' not found in JWKS"
            case .missingKIDHeader:
                return "JWT has no 'kid' header - cannot select a key from JWKS"
            case .signatureVerificationFailed:
                return "Invalid signature"
            case .claimVerificationFailure:
                let reason = jwt.reason.map { ": \($0)" } ?? ""
                return "Claim verification failed\(reason)"
            case .malformedToken:
                let reason = jwt.reason.map { ": \($0)" } ?? ""
                return "Malformed token\(reason)"
            case .noKeyProvided:
                return "No verification key available"
            default:
                return jwt.reason ?? error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    struct Claims: JWTPayload {
        func verify(using algorithm: some JWTAlgorithm) throws {}
    }

    // MARK: - Decoding

    private func sanitizeAndDecode() {
        let stripped = encodedToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.hasPrefix("\"") && stripped.hasSuffix("\"") && stripped.count >= 2 {
            encodedToken = String(stripped.dropFirst().dropLast())
        } else {
            decodeToken()
        }
    }

    private func decodeToken() {
        guard !encodedToken.isEmpty else {
            headerValue = .null; headerText = ""
            payloadValue = .null; payloadText = ""
            return
        }
        let parts = encodedToken.split(separator: ".")
        guard parts.count >= 2 else {
            headerValue = .string("Invalid Token Structure")
            payloadValue = .string("Invalid Token Structure")
            headerText = "Invalid Token Structure"
            payloadText = "Invalid Token Structure"
            return
        }
        let headerData = base64UrlDecode(String(parts[0]))
        let payloadData = base64UrlDecode(String(parts[1]))
        headerValue = parseValue(headerData)
        payloadValue = parseValue(payloadData)
        headerText = prettyPrint(headerData)
        payloadText = prettyPrint(payloadData)
    }

    private func parseValue(_ data: Data?) -> JSONValue {
        guard let data, let obj = try? JSONSerialization.jsonObject(with: data) else {
            return .string("Failed to decode")
        }
        return JSONValue.from(obj)
    }

    private func prettyPrint(_ data: Data?) -> String {
        guard let data,
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .withoutEscapingSlashes]),
              let str = String(data: pretty, encoding: .utf8) else {
            return "Failed to decode"
        }
        return str
    }

    private func base64UrlDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        return Data(base64Encoded: base64)
    }
}
