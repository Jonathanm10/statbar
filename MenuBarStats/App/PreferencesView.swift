import SwiftUI
import MenuBarStatsFeature

struct PreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        VStack(spacing: 10) {
            generalCard

            FeatureSettingsSectionsView(
                settings: Binding(
                    get: { viewModel.featureSettings },
                    set: viewModel.updateFeatureSettings
                )
            )
        }
        .padding(20)
        .frame(width: 420)
    }

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("General")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { viewModel.launchAtLoginState.isEnabled },
                    set: viewModel.setLaunchAtLoginEnabled
                )
            )
            .font(.subheadline)

            if let detailText = viewModel.launchAtLoginState.detailText {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }
}
