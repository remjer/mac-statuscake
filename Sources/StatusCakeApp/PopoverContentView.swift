import SwiftUI

/// Settings are a second view in the same popover rather than a window of
/// their own; `model.showingSettings` is the single switch between them so
/// `AppDelegate` can also read and drive it (Esc needs to know which view is
/// up, and closing the popover needs to reset it back to the list).
struct PopoverContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.showingSettings {
            SettingsView(model: model)
        } else {
            StatusListView(model: model)
        }
    }
}
