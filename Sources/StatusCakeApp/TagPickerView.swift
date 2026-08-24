import SwiftUI
import StatusCakeCore

/// Tags picked from the account's own list rather than typed. The available
/// list comes from an unfiltered fetch every time this view appears, so a tag
/// added in StatusCake shows up the next time settings is opened, and a tag
/// just deselected here doesn't vanish from the list before it can be
/// reselected -- see `distinctTags`.
struct TagPickerView: View {
    @ObservedObject var model: AppModel

    @State private var availableTags: [String] = []
    @State private var isLoading = true
    @State private var search = ""

    private var selected: Set<String> {
        Set(tagList(model.settings.tags))
    }

    private var filteredTags: [String] {
        guard !search.isEmpty else { return availableTags }
        return availableTags.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.settings.tags.isEmpty ? "no tags selected" : model.settings.tags)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search tags…", text: $search)
                .textFieldStyle(.roundedBorder)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, alignment: .center)
            } else if availableTags.isEmpty {
                Text("No tags on this account").font(.caption).foregroundStyle(.secondary)
            } else if filteredTags.isEmpty {
                Text("No tags match \u{201C}\(search)\u{201D}").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredTags, id: \.self) { tag in
                            Toggle(tag, isOn: Binding(
                                get: { selected.contains(tag) },
                                set: { isOn in toggle(tag, isOn: isOn) }
                            ))
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                .frame(maxHeight: 140)
            }
        }
        .task { await reload() }
    }

    private func toggle(_ tag: String, isOn: Bool) {
        var values = selected
        if isOn { values.insert(tag) } else { values.remove(tag) }
        model.updateTags(joinTags(Array(values)))
    }

    private func reload() async {
        isLoading = true
        availableTags = await model.fetchAvailableTags()
        isLoading = false
    }
}
