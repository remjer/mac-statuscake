import SwiftUI
import StatusCakeCore

/// The second view in the same popover, matching the reference's own
/// reasoning: settings are not worth a separate window for an app that lives
/// entirely in one menu bar click.
struct SettingsView: View {
    @ObservedObject var model: AppModel

    @State private var tokenField = ""
    @State private var isSaving = false
    @State private var tokenError = ""
    @State private var confirmingRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    tokenSection
                    if !model.settingsBlocked {
                        refreshSection
                        tagsSection
                        notifySection
                    }
                }
                .padding()
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 420)
    }

    private var header: some View {
        HStack {
            Button(action: { model.showingSettings = false }) {
                Image(systemName: "chevron.left")
                Text("Settings")
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding()
    }

    // MARK: - Token

    private var tokenSection: some View {
        let state = model.tokenStateInfo
        return VStack(alignment: .leading, spacing: 8) {
            Label(state.text, systemImage: state.icon.sfSymbolName)
                .foregroundStyle(state.tone.color)
                .font(.callout)

            SecureField("Paste your StatusCake API token", text: $tokenField)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)

            if !tokenError.isEmpty {
                Text(tokenError).font(.caption).foregroundStyle(.red)
            }

            Text(model.tokenSaveHintText)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(isSaving ? "Saving…" : "Save") { save() }
                    .disabled(tokenField.isEmpty || isSaving)

                if model.tokenIsRemovable {
                    Button("Remove token", role: .destructive) {
                        confirmingRemoval = true
                    }
                }
            }
        }
        .confirmationDialog(
            model.tokenRemoveConfirmText,
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await model.removeToken() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func save() {
        guard !tokenField.isEmpty else { return }
        isSaving = true
        tokenError = ""
        Task {
            let result = await model.saveToken(tokenField)
            isSaving = false
            switch result {
            case .success:
                tokenField = ""
                model.showingSettings = false
            case .failure(let error):
                tokenError = error.message
            }
        }
    }

    // MARK: - Other settings

    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Refresh interval").font(.subheadline)
            Stepper(
                "\(model.settings.refreshIntervalSec / 60) min",
                value: Binding(
                    get: { model.settings.refreshIntervalSec },
                    set: { model.updateRefreshIntervalSec($0) }
                ),
                in: 60...3600,
                step: 60
            )
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tags").font(.subheadline)
            TextField(
                "prod, web",
                text: Binding(
                    get: { model.settings.tags },
                    set: { model.updateTags($0) }
                )
            )
            .textFieldStyle(.roundedBorder)

            Toggle(
                "Match any tag",
                isOn: Binding(
                    get: { model.settings.matchAnyTag },
                    set: { model.updateMatchAnyTag($0) }
                )
            )
            // The API rejects matchany with no tags, and fetchParameters
            // drops it, so a control the user could still flip would lie.
            .disabled(model.settings.tags.isEmpty)

            Text(
                model.settings.tags.isEmpty
                    ? "Add tags above to use this."
                    : "Show checks carrying any of those tags, not only those carrying all of them."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var notifySection: some View {
        Toggle(
            "Notify on status change",
            isOn: Binding(
                get: { model.settings.notify },
                set: { model.updateNotify($0) }
            )
        )
    }
}
