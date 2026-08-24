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
            Button(action: { model.showingSettings = true }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
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
        // The one error the user can fix from here gets a button straight
        // into settings, rather than just repeating the fetch failure they
        // already know about (they never set up a token, or it stopped
        // working).
        if needsToken(model.summary) || tokenRejected(model.summary) {
            VStack(alignment: .leading, spacing: 8) {
                Text(needsToken(model.summary) ? "No API token yet." : "StatusCake rejected the token.")
                    .foregroundStyle(.secondary)
                Button(needsToken(model.summary) ? "Set one up →" : "Replace the token →") {
                    model.showingSettings = true
                }
                .buttonStyle(.plain)
            }
            .padding()
        } else if let error = model.summary.error {
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
