import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Group {
            if viewModel.selectedLanguage == "ar" {
                content
                    .environment(\.locale, Locale(identifier: "ar"))
                    .environment(\.layoutDirection, .rightToLeft)
            } else if viewModel.selectedLanguage == "en" {
                content
                    .environment(\.locale, Locale(identifier: "en"))
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                content
            }
        }
        .frame(width: 480, height: 420)
    }

    private var content: some View {
        TabView {
            BreaksTabView(viewModel: viewModel)
                .tabItem {
                    Label("Breaks", systemImage: "timer")
                }

            BehaviorTabView(viewModel: viewModel)
                .tabItem {
                    Label("Behavior", systemImage: "gearshape.2")
                }

            GeneralTabView(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "wrench.and.screwdriver")
                }

            AboutTabView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
    }
}
