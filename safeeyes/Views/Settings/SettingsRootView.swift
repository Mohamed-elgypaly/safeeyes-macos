import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            BreaksTabView(viewModel: viewModel)
                .tabItem {
                    Label(LocalizedStringKey("Breaks"), systemImage: "timer")
                }

            BehaviorTabView(viewModel: viewModel)
                .tabItem {
                    Label(LocalizedStringKey("Behavior"), systemImage: "gearshape.2")
                }

            GeneralTabView(viewModel: viewModel)
                .tabItem {
                    Label(LocalizedStringKey("General"), systemImage: "wrench.and.screwdriver")
                }

            AboutTabView()
                .tabItem {
                    Label(LocalizedStringKey("About"), systemImage: "info.circle")
                }
        }
        .id(viewModel.appLanguage)
        .frame(width: 480, height: 420)
        .environment(\.locale, Locale(identifier: viewModel.appLanguage))
        .environment(\.layoutDirection, viewModel.appLanguage == "ar" ? .rightToLeft : .leftToRight)
    }
}
