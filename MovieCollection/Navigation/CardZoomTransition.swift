//
//  CardZoomTransition.swift
//  MovieCollection
//
//  Purpose: Lets a tapped shelf poster zoom into the flip-card viewer.
//  RootTabView provides the shared namespace; the shelf marks each poster as
//  a zoom source, and the viewer zooms in from the tapped one.
//  Used in: RootTabView, ShelfView.
//

import SwiftUI

extension EnvironmentValues {
    /// The namespace shelf posters and the card viewer share for the zoom transition.
    @Entry var cardZoomNamespace: Namespace.ID? = nil
}

extension View {
    /// Marks this view as the place a zoom transition starts from (when a namespace is available).
    @ViewBuilder
    func cardZoomSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Zooms this pushed screen in from the matching source (when a namespace is available).
    @ViewBuilder
    func cardZoomTransition(sourceID: some Hashable, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}
