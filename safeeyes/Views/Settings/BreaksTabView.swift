import SwiftUI

struct BreaksTabView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Stepper(
                    "Short break every \(viewModel.shortBreakIntervalMinutes) min",
                    value: $viewModel.shortBreakIntervalMinutes,
                    in: 1...120,
                    step: 1
                )
                .accessibilityLabel("Short break interval in minutes")

                Stepper(
                    "Short break duration: \(viewModel.shortBreakDurationSeconds) sec",
                    value: $viewModel.shortBreakDurationSeconds,
                    in: 5...300,
                    step: 5
                )
                .accessibilityLabel("Short break duration in seconds")
            } header: {
                Label("Short Breaks", systemImage: "eye")
            }

            Section {
                Stepper(
                    "Long break every \(viewModel.longBreakEveryNShortBreaks) short breaks",
                    value: $viewModel.longBreakEveryNShortBreaks,
                    in: 1...20,
                    step: 1
                )
                .accessibilityLabel("Long break cadence")

                Stepper(
                    "Long break duration: \(viewModel.longBreakDurationMinutes) min",
                    value: $viewModel.longBreakDurationMinutes,
                    in: 1...30,
                    step: 1
                )
                .accessibilityLabel("Long break duration in minutes")
            } header: {
                Label("Long Breaks", systemImage: "figure.walk")
            }

            Section {
                Stepper(
                    "Pre-break notice: \(viewModel.preBreakNoticeSeconds) sec",
                    value: $viewModel.preBreakNoticeSeconds,
                    in: 0...60,
                    step: 5
                )
                .accessibilityLabel("Pre-break notification lead time")
            } header: {
                Label("Notification", systemImage: "bell")
            }
        }
        .formStyle(.grouped)
    }
}
