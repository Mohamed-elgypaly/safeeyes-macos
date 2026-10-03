import SwiftUI

struct BehaviorTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Toggle("Strict Mode", isOn: $viewModel.strictMode)
                    .accessibilityLabel("Strict mode")
                    .accessibilityHint("When enabled, breaks cannot be skipped or postponed")

                Toggle("Allow Postpone", isOn: $viewModel.allowPostpone)
                    .disabled(viewModel.isPostponeDisabled)
                    .accessibilityLabel("Allow postponing breaks")

                if viewModel.isPostponeDisabled {
                    Text("Postpone is disabled in Strict Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if viewModel.allowPostpone && !viewModel.strictMode {
                    Stepper(
                        "Postpone duration: \(viewModel.postponeMinutes) min",
                        value: $viewModel.postponeMinutes,
                        in: 1...30,
                        step: 1
                    )
                    .accessibilityLabel("Postpone duration in minutes")
                }
            } header: {
                Label("Break Enforcement", systemImage: "lock.shield")
            }

            Section {
                Stepper(
                    "Idle pause after \(viewModel.idlePauseThresholdSeconds) sec",
                    value: $viewModel.idlePauseThresholdSeconds,
                    in: 5...600,
                    step: 5
                )
                .accessibilityLabel("Idle pause threshold in seconds")
            } header: {
                Label("Idle Detection", systemImage: "moon.zzz")
            }

            Section {
                Toggle("Play Sounds", isOn: $viewModel.playSounds)
                    .accessibilityLabel("Play end-of-break chime")

                Toggle("Show Exercises", isOn: $viewModel.showExercises)
                    .accessibilityLabel("Show exercise suggestions during breaks")
            } header: {
                Label("Extras", systemImage: "sparkles")
            }
        }
        .formStyle(.grouped)
    }
}
