import SwiftUI

public struct SecondaryScreenView: View {
    @ObservedObject public var viewModel: BreakViewModel

    public init(viewModel: BreakViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(viewModel.formattedRemaining)
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                Text("Rest Your Eyes")
                    .font(.system(size: 18, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
