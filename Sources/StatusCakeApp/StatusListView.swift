import SwiftUI
import StatusCakeCore

/// The popover's content. `StatusCakeCore` already decided the order
/// (`Summary.checks` is pre-sorted down-first) and the display strings
/// (`formatUptime`); this view only lays them out.
struct StatusListView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 320)
        .frame(maxHeight: 420)
    }

    private var header: some View {
        HStack {
            Text("StatusCake").font(.headline)
            Spacer()
            Text(counts).foregroundStyle(.secondary)
        }
        .padding()
    }

    private var counts: String {
        let summary = model.summary
        var parts = ["\(summary.up) up", "\(summary.down) down"]
        if summary.paused > 0 { parts.append("\(summary.paused) paused") }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var content: some View {
        if let error = model.summary.error {
            Text(error.message)
                .foregroundStyle(.secondary)
                .padding()
        } else if !model.summary.hasData {
            Text("Loading…")
                .foregroundStyle(.secondary)
                .padding()
        } else if model.summary.checks.isEmpty {
            Text("No checks on this account.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.summary.checks, id: \.id) { check in
                        CheckRow(check: check)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct CheckRow: View {
    let check: Check

    var body: some View {
        HStack {
            Image(systemName: check.paused ? "pause.circle" : check.status.sfSymbolName)
                .foregroundStyle(tint)
            Text(check.name).lineLimit(1)
            Spacer()
            Text(formatUptime(check.uptime))
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var tint: Color {
        if check.paused { return .secondary }
        switch check.status {
        case .up: return .green
        case .down: return .red
        case .unknown: return .secondary
        }
    }
}
