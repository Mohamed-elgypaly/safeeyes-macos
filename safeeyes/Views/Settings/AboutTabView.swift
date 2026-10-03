import SwiftUI

struct AboutTabView: View {
    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    private let buildNumber: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }()

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "eye")
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SafeEyes")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Text("Protect your eyes from eye strain with regular break reminders.")
                    .font(.body)
                    .foregroundColor(.secondary)
            } header: {
                Label("About", systemImage: "info.circle")
            }

            Section {
                Link(destination: URL(string: "https://github.com/slgobinern/SafeEyes")!) {
                    HStack {
                        Image(systemName: "link")
                        Text("SafeEyes on GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel("Open SafeEyes GitHub page")
            } header: {
                Label("Links", systemImage: "globe")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GNU General Public License v3.0")
                        .font(.system(size: 13, weight: .medium))
                    Text("SafeEyes is free software. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 2)
            } header: {
                Label("License", systemImage: "doc.text")
            }
        }
        .formStyle(.grouped)
    }
}
