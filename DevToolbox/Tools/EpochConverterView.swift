import SwiftUI
import Combine

// MARK: - Supporting Types

enum TimestampUnit: String, CaseIterable {
    case seconds      = "s"
    case milliseconds = "ms"
    case microseconds = "µs"
    case nanoseconds  = "ns"

    var label: String { rawValue }
    var factor: Double {
        switch self {
        case .seconds:      1
        case .milliseconds: 1_000
        case .microseconds: 1_000_000
        case .nanoseconds:  1_000_000_000
        }
    }
}

// MARK: - Main View

struct EpochConverterView: View {

    // Live clock
    @State private var nowTimestamp: Int = Int(Date().timeIntervalSince1970)

    // Single source of truth shared by both panels
    @State private var selectedDate: Date = Date()

    // Timestamp → Date panel
    @State private var timestampInput: String = String(Int(Date().timeIntervalSince1970))
    @State private var selectedUnit: TimestampUnit = .seconds

    // Shared timezone (both panels stay in sync)
    @State private var timezoneID: String = TimeZone.current.identifier

    // Focus
    @FocusState private var isTimestampFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                liveBanner
                Divider()
                timestampToDatePanel.padding(20)
                Divider()
                dateToTimestampPanel.padding(20)
            }
        }
        .navigationTitle("Epoch Converter")
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            nowTimestamp = Int(Date().timeIntervalSince1970)
        }
        .onAppear {
            applyPendingInput()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isTimestampFocused = true
            }
        }
        .onChange(of: AppState.shared.pendingInput) { applyPendingInput() }
        // Typing in timestamp field → update unit and selectedDate
        .onChange(of: timestampInput) {
            selectedUnit = autoDetectUnit(from: timestampInput)
            if let value = Double(timestampInput.trimmingCharacters(in: .whitespaces)) {
                let utcEpoch = value / selectedUnit.factor
                let newDate = selectedDateForEpoch(utcEpoch, timezoneID: timezoneID)
                if abs(newDate.timeIntervalSince(selectedDate)) > 0.5 {
                    selectedDate = newDate
                }
            }
        }
        // Date picker changed → reflect in timestamp field
        .onChange(of: selectedDate) {
            let newInput = safeFormat(epochSeconds * selectedUnit.factor)
            if newInput != timestampInput { timestampInput = newInput }
        }
        // Timezone changed → keep the epoch constant, update DatePicker display
        .onChange(of: timezoneID) {
            if let value = Double(timestampInput.trimmingCharacters(in: .whitespaces)) {
                let utcEpoch = value / selectedUnit.factor
                selectedDate = selectedDateForEpoch(utcEpoch, timezoneID: timezoneID)
            }
        }
    }

    // MARK: - Live Banner

    private var liveBanner: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.green).frame(width: 8, height: 8)
            Text("Current Unix time").foregroundStyle(.secondary).font(.callout)
            Text(String(nowTimestamp))
                .font(.system(.body, design: .monospaced)).fontWeight(.medium)
            Spacer()
            CopyButton(value: String(nowTimestamp))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Timestamp → Date

    private var timestampToDatePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timestamp → Date").font(.headline)

            HStack(spacing: 10) {
                TextField("Unix timestamp", text: $timestampInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 240)
                    .focused($isTimestampFocused)

                Text("Auto: \(selectedUnit.label)")
                    .foregroundStyle(.secondary).font(.callout)

                Spacer()

                TimezonePicker(identifier: $timezoneID)
            }

            if let date = convertedDate {
                VStack(spacing: 8) {
                    OutputRow(label: "Date",     value: localeString(for: date))
                    OutputRow(label: "ISO 8601", value: iso8601String(for: date))
                    OutputRow(label: "Relative", value: relativeString(for: date), copyable: false)
                }
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 1))
            } else if !timestampInput.isEmpty {
                Text("Invalid timestamp").foregroundStyle(.red).font(.callout)
            }
        }
    }

    // MARK: - Date → Timestamp

    private var dateToTimestampPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date → Timestamp").font(.headline)

            HStack(spacing: 10) {
                DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                Spacer()
                TimezonePicker(identifier: $timezoneID)
            }

            VStack(spacing: 8) {
                OutputRow(label: "Seconds",      value: asSeconds)
                OutputRow(label: "Milliseconds", value: asMilliseconds)
                OutputRow(label: "Microseconds", value: asMicroseconds)
                OutputRow(label: "Nanoseconds",  value: asNanoseconds)
            }
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 1))
        }
    }

    // MARK: - Conversion Logic

    private func autoDetectUnit(from input: String) -> TimestampUnit {
        let digits = input.filter(\.isNumber).count
        switch digits {
        case ..<11:   return .seconds
        case 11...13: return .milliseconds
        case 14...16: return .microseconds
        default:      return .nanoseconds
        }
    }

    private var convertedDate: Date? {
        guard let value = Double(timestampInput.trimmingCharacters(in: .whitespaces)) else { return nil }
        return Date(timeIntervalSince1970: value / selectedUnit.factor)
    }

    private func localeString(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .medium
        fmt.timeZone = TimeZone(identifier: timezoneID) ?? .current
        return fmt.string(from: date)
    }

    private func iso8601String(for date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone(identifier: timezoneID) ?? .current
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.string(from: date)
    }

    private func relativeString(for date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    // The UTC epoch for the moment currently shown in the DatePicker,
    // interpreted as a wall-clock time in dateTimezoneID.
    private var epochSeconds: Double {
        let tz = TimeZone(identifier: timezoneID) ?? .current
        let local  = Double(TimeZone.current.secondsFromGMT(for: selectedDate))
        let target = Double(tz.secondsFromGMT(for: selectedDate))
        return selectedDate.timeIntervalSince1970 + local - target
    }

    // Converts a UTC epoch to the selectedDate value that makes the DatePicker
    // show the correct wall-clock time for timezoneID.
    private func selectedDateForEpoch(_ utcEpoch: Double, timezoneID: String) -> Date {
        let approx   = Date(timeIntervalSince1970: utcEpoch)
        let tz       = TimeZone(identifier: timezoneID) ?? .current
        let local    = Double(TimeZone.current.secondsFromGMT(for: approx))
        let target   = Double(tz.secondsFromGMT(for: approx))
        return Date(timeIntervalSince1970: utcEpoch - local + target)
    }

    private var asSeconds:      String { safeFormat(epochSeconds) }
    private var asMilliseconds: String { safeFormat(epochSeconds * 1_000) }
    private var asMicroseconds: String { safeFormat(epochSeconds * 1_000_000) }
    private var asNanoseconds:  String { safeFormat(epochSeconds * 1_000_000_000) }

    private func safeFormat(_ value: Double) -> String {
        guard value.isFinite,
              value >= Double(Int64.min),
              value <= Double(Int64.max) else { return "-" }
        return String(Int64(value))
    }

    // MARK: - Pending Input

    private func applyPendingInput() {
        guard let pending = AppState.shared.pendingInput,
              pending.tool == .epochConverter else { return }
        timestampInput = pending.content.trimmingCharacters(in: .whitespacesAndNewlines)
        AppState.shared.pendingInput = nil
    }
}

// MARK: - Timezone Picker

private struct TimezonePicker: View {
    @Binding var identifier: String
    @State private var isPresented = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [TZEntry] {
        let q = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return TZEntry.curated }

        let matched = TZEntry.curated.filter { entry in
            entry.city.lowercased().contains(q) ||
            entry.country.lowercased().contains(q) ||
            entry.abbr.lowercased().contains(q) ||
            entry.tzID.lowercased().contains(q) ||
            entry.also.contains { $0.lowercased().contains(q) } ||
            TimeZone(identifier: entry.tzID)?.abbreviation()?.lowercased() == q
        }

        let matchedIDs = Set(matched.map(\.tzID))
        let fallbacks = TimeZone.knownTimeZoneIdentifiers
            .filter { !matchedIDs.contains($0) && $0.localizedCaseInsensitiveContains(searchText) }
            .sorted()
            .map { id -> TZEntry in
                let city = id.split(separator: "/").last
                    .map { String($0).replacingOccurrences(of: "_", with: " ") } ?? id
                return TZEntry(tzID: id, city: city, country: "", abbr: "", also: [])
            }

        return matched + fallbacks
    }

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 4) {
                Text(buttonLabel).lineLimit(1).font(.callout)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(spacing: 0) {
            TextField("Search by city, country, or abbreviation…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .focused($searchFocused)
                .onAppear { searchFocused = true }

            Divider()

            List(filtered) { entry in
                Button {
                    identifier = entry.tzID
                    isPresented = false
                    searchText = ""
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.city)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            if !entry.country.isEmpty {
                                Text(entry.country)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(TimeZone(identifier: entry.tzID)?.abbreviation() ?? entry.abbr.components(separatedBy: " ").first ?? "")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                        Text(utcOffsetString(for: entry.tzID))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(entry.tzID == identifier ? Color.accentColor.opacity(0.12) : Color.clear)
            }
        }
        .frame(width: 380, height: 400)
    }

    private var buttonLabel: String {
        let entry = TZEntry.curated.first { $0.tzID == identifier }
        let city = entry?.city ?? identifier.split(separator: "/").last
            .map { String($0).replacingOccurrences(of: "_", with: " ") } ?? identifier
        let abbr = TimeZone(identifier: identifier)?.abbreviation() ?? ""
        let offset = utcOffsetString(for: identifier)
        return "\(city)  \(abbr)  \(offset)"
    }

    private func utcOffsetString(for id: String) -> String {
        guard let tz = TimeZone(identifier: id) else { return "" }
        let off = tz.secondsFromGMT()
        let h   = abs(off) / 3600
        let m   = (abs(off) % 3600) / 60
        return String(format: "UTC%@%02d:%02d", off >= 0 ? "+" : "-", h, m)
    }
}

// MARK: - Reusable subviews

private struct OutputRow: View {
    let label: String
    let value: String
    var copyable: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
                .font(.callout)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if copyable { CopyButton(value: value) }
        }
    }
}

private struct CopyButton: View {
    let value: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? .green : .secondary)
                .frame(width: 16)
        }
        .buttonStyle(.plain)
    }
}
