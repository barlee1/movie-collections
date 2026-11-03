//
//  EditSubscriptionsSheet.swift
//  MovieCollection
//
//  Purpose: Lets the user choose which streaming services they pay for. Changes
//  are a draft until Save, so Cancel leaves their services as they were.
//  Used in: ProfileView. ServicePickerList is also used in OnboardingView.
//

import SwiftUI

struct EditSubscriptionsSheet: View {
    /// Called with the chosen services when Save is tapped.
    let onSave: (Set<StreamingService>) -> Void

    @State private var selected: Set<StreamingService>
    @Environment(\.dismiss) private var dismiss

    init(current: [StreamingService], onSave: @escaping (Set<StreamingService>) -> Void) {
        self.onSave = onSave
        _selected = State(initialValue: Set(current))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pick the services you subscribe to. They show on your profile and in the shelf's filters.")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.bottom, 6)

                    ServicePickerList(selected: $selected)
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 12)
            }
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Streaming Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selected)
                        dismiss()
                    }
                }
            }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.large])
    }
}

/// A check row for each subscription service. Shared with onboarding.
struct ServicePickerList: View {
    @Binding var selected: Set<StreamingService>

    var body: some View {
        ForEach(StreamingService.subscriptions) { service in
            Toggle(
                service.rawValue,
                isOn: Binding(
                    get: { selected.contains(service) },
                    set: { _ in selected.toggle(service) }
                )
            )
            .toggleStyle(.checkRow())
        }
    }
}

#Preview {
    Text("Profile")
        .sheet(isPresented: .constant(true)) {
            EditSubscriptionsSheet(current: [.netflix, .amazonPrime]) { _ in }
        }
}
