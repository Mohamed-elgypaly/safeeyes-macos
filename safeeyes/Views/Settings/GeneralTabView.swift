import SwiftUI

struct GeneralTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch SafeEyes at Login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
                .accessibilityLabel("Launch SafeEyes at login")

                if viewModel.loginItemRequiresApproval {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("macOS requires user approval in System Settings for SafeEyes to launch at login.")
                            .font(.footnote)
                            .foregroundColor(.orange)

                        Button("Open Login Items Settings") {
                            viewModel.openLoginItemsSettings()
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Label("Startup", systemImage: "power")
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset All Settings to Defaults")
                    }
                }
                .accessibilityLabel("Reset all settings to default values")
                .confirmationDialog(
                    "Reset all settings to their default values?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        viewModel.resetToDefaults()
                    }
                    Button("Cancel", role: .cancel) { }
                }
            } header: {
                Label("Reset", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .formStyle(.grouped)
    }
}
