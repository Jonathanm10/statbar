import SwiftUI

public struct FeatureSettingsSectionsView: View {
    @Binding private var settings: FeatureSettings

    public init(settings: Binding<FeatureSettings>) {
        _settings = settings
    }

    public var body: some View {
        VStack(spacing: 10) {
            settingsCard(icon: "arrow.clockwise", title: "Refresh") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Update interval")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $settings.refreshPreset) {
                        ForEach(RefreshPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            settingsCard(icon: "menubar.rectangle", title: "Menu Bar") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display format")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $settings.menuBarDisplayFormat) {
                        ForEach(MenuBarDisplayFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            settingsCard(icon: "macwindow", title: "Popover") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processes shown")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $settings.processCount) {
                            ForEach(ProcessCountOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Divider()

                    Toggle("Show process IDs", isOn: $settings.showsPID)
                        .font(.subheadline)
                    Toggle("Show disk usage", isOn: $settings.showsDiskStats)
                        .font(.subheadline)
                }
            }
        }
    }

    private func settingsCard<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }
}
