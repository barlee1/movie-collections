//
//  CheckRow.swift
//  MovieCollection
//
//  Purpose: A tappable check-off row ("Watched", "Reviewed") with a circle that
//  fills with a check when on. Built as a ToggleStyle, so VoiceOver announces
//  it as a switch that's on or off.
//  Used in: TitleDetailView.
//

import SwiftUI

struct CheckRowToggleStyle: ToggleStyle {
    /// Smaller line under the label, e.g. "Last watched Oct 21, 2026".
    var detail: String?

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        configuration.isOn ? Theme.Colors.onHighlight : Theme.Colors.textPlaceholder,
                        configuration.isOn ? Theme.Colors.highlight : Theme.Colors.textPlaceholder
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    configuration.label
                        .font(Theme.Fonts.body(16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.text)
                    if let detail {
                        Text(detail)
                            .font(Theme.Fonts.body(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .strokeBorder(
                        configuration.isOn ? Theme.Colors.highlight : Theme.Colors.divider,
                        lineWidth: configuration.isOn ? 1.5 : 1)
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.pressableCard)
        .sensoryFeedback(.success, trigger: configuration.isOn) { _, isOn in isOn }
        .accessibilityRepresentation {
            // The detail line is read as a hint, so VoiceOver still announces on/off as the value.
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .accessibilityHint(detail ?? "")
        }
    }
}

extension ToggleStyle where Self == CheckRowToggleStyle {
    /// A check-off row with an optional detail line.
    static func checkRow(detail: String? = nil) -> CheckRowToggleStyle {
        CheckRowToggleStyle(detail: detail)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var watched = true
    @Previewable @State var reviewed = false
    VStack(spacing: 10) {
        Toggle("Watched", isOn: $watched)
            .toggleStyle(.checkRow(detail: watched ? "Last watched Oct 21, 2026" : "Not watched yet"))
        Toggle("Reviewed", isOn: $reviewed)
            .toggleStyle(.checkRow(detail: reviewed ? "Tap the stars to rate it" : "Not reviewed yet"))
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}
