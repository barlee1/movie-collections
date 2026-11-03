//
//  navBar.swift
//  MovieCollection
//
//  Created by Kylee Brown on 9/24/26.
//
//
//  Purpose: The app's bottom tab bar: five icon-and-label buttons on the
//  nav bar color, with a highlight-colored pill behind the active tab.
//  Used in: RootTabView
//

import SwiftUI

struct navBar: View {
    let selectedTab: AppTab
    let onSelect: (AppTab) -> Void

    /// Compact height means landscape on iPhone, where the bar gets much shorter.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isCompact: Bool { verticalSizeClass == .compact }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(for: tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, isCompact ? 4 : 8)
        .padding(.bottom, isCompact ? 0 : 4)
        .background(Theme.Colors.navBar.ignoresSafeArea(edges: .bottom))
        // Keep the bar a fixed shape at the largest accessibility text sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private func tabButton(for tab: AppTab) -> some View {
        let isSelected = tab == selectedTab
        return Button {
            onSelect(tab)
        } label: {
            // Portrait stacks the icon over the label; landscape puts them side by side.
            let layout =
                isCompact
                ? AnyLayout(HStackLayout(spacing: 6))
                : AnyLayout(VStackLayout(spacing: 4))
            layout {
                Image(systemName: tab.systemImage)
                    .font(.system(size: isCompact ? 17 : 20, weight: .bold))
                    .frame(height: isCompact ? 20 : 24)
                Text(tab.label)
                    .font(Theme.Fonts.body(12, weight: .semibold, relativeTo: .caption))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Theme.Colors.navBarActiveContent : Theme.Colors.navBarContent)
            .padding(.horizontal, isCompact ? 14 : 0)
            .frame(minWidth: 64, minHeight: isCompact ? 36 : 56)
            .background(isSelected ? Theme.Colors.navBarActive : .clear, in: .rect(cornerRadius: 18))
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview("Shelf selected") {
    VStack {
        Spacer()
        navBar(selectedTab: .shelf) { _ in }
    }
    .background(Theme.Colors.background)
}

#Preview("Profile selected") {
    VStack {
        Spacer()
        navBar(selectedTab: .profile) { _ in }
    }
    .background(Theme.Colors.background)
}
