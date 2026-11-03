//
//  ScanCoverView.swift
//  MovieCollection
//
//  Purpose: Add a movie by reading its case. Point the camera at the front of a
//  DVD or Blu-ray (live text recognition), or choose a photo; the title is read
//  on the phone with Vision and matched against the catalog. Picking a match
//  opens the add form, already filled in.
//  Used in: RootTabView (Route.scanCover), opened from the Add tab.
//

import PhotosUI
import SwiftUI
import VisionKit

struct ScanCoverView: View {
    @State private var viewModel: CoverScanViewModel
    @State private var photoItem: PhotosPickerItem?
    /// The photo (or sample cover) being read, shown so the user sees what was scanned.
    @State private var previewImage: UIImage?
    @Environment(AppRouter.self) private var router

    init(appModel: AppViewModel) {
        _viewModel = State(initialValue: CoverScanViewModel(appModel: appModel))
    }

    /// Live scanning needs a supported camera (not available in the Simulator).
    private var canScanLive: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BackButton()
                ScreenHeader(
                    title: "Scan a cover",
                    subtitle: "Point your camera at the front of a case, or choose a photo. The title is read on your phone and never leaves it.",
                    titleSize: 34
                )

                camera
                sourceButtons

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(.rect(cornerRadius: Theme.Radius.md))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("The cover being read")
                }

                if viewModel.isReading {
                    HStack(spacing: 10) {
                        ProgressView().tint(Theme.Colors.action)
                        Text("Reading the cover…").font(Theme.Fonts.body(15))
                    }
                }

                results
                recognizedText
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .themedScreen()
        .onChange(of: photoItem) {
            guard let photoItem else { return }
            Task { await read(photoItem) }
        }
        .alert("Couldn't read the cover", isPresented: errorIsShowing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .animation(.snappy, value: viewModel.matches)
    }

    // MARK: - Camera

    @ViewBuilder
    private var camera: some View {
        if canScanLive {
            LiveCoverScanner(onText: viewModel.updateLiveText)
                .frame(height: 280)
                .clipShape(.rect(cornerRadius: Theme.Radius.poster))
                .overlay(alignment: .bottom) {
                    Text("Hold the title inside the frame")
                        .font(Theme.Fonts.body(13, weight: .semibold, relativeTo: .footnote))
                        .foregroundStyle(Theme.Colors.posterTitle)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.posterInk.opacity(0.7), in: Capsule())
                        .padding(12)
                }
                .accessibilityLabel("Camera view for reading a movie case")
        } else {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "camera.badge.ellipsis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .accessibilityHidden(true)
                Text("Live scanning needs a camera, so it isn't available here. Choose a photo or try the sample cover.")
                    .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .cardStyle(padding: 16, bordered: true)
        }
    }

    private var sourceButtons: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo")
            }
            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 46))

            Button("Try a sample") {
                Task { await readSampleCover() }
            }
            .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 15, height: 46))
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        if !viewModel.matches.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Looks like", size: 12)
                ForEach(viewModel.matches) { movie in
                    matchRow(movie)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if viewModel.hasScanned, !viewModel.isReading {
            VStack(alignment: .leading, spacing: 10) {
                Text("No match in our catalog")
                    .font(Theme.Fonts.heading(18, relativeTo: .headline))
                Text("Try a clearer shot of the title, or add it by hand.")
                    .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
                Button("Type it in instead") { router.push(.addTitle()) }
                    .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 15, height: 42, fullWidth: false))
            }
            .cardStyle(padding: 18, bordered: true)
        }
    }

    private func matchRow(_ movie: Movie) -> some View {
        HStack(spacing: 12) {
            PosterArt(title: movie.title, letter: movie.posterLetter)
                .frame(width: 40, height: 56)
                .clipShape(.rect(cornerRadius: Theme.Radius.sm))
            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(Theme.Fonts.heading(17, relativeTo: .headline))
                Text([movie.year.map(String.init), movie.director].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Spacer(minLength: 8)
            if viewModel.isOnShelf(movie) {
                TagView(text: "On your shelf", style: .secondary)
            } else {
                Button("Add") { router.push(.addTitle(prefillMovieID: movie.id)) }
                    .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 40, fullWidth: false))
                    .accessibilityLabel("Add \(movie.title)")
            }
        }
        .cardStyle(padding: 12)
    }

    @ViewBuilder
    private var recognizedText: some View {
        if !viewModel.recognizedLines.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(viewModel.recognizedLines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(Theme.Fonts.body(14, relativeTo: .subheadline))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            } label: {
                Text("Text we read")
                    .font(Theme.Fonts.body(14, weight: .semibold, relativeTo: .subheadline))
            }
            .tint(Theme.Colors.link)
        }
    }

    // MARK: - Reading

    private func read(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.errorMessage = "That photo couldn't be loaded."
            return
        }
        previewImage = UIImage(data: data)
        await viewModel.read(imageData: data)
    }

    /// Renders a sample movie case and reads it, so scanning can be tried
    /// without a camera or a photo (for example in the Simulator).
    private func readSampleCover() async {
        let renderer = ImageRenderer(content: SampleCoverArt())
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        previewImage = image
        await viewModel.read(imageData: data)
    }

    private var errorIsShowing: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

// MARK: - Live camera scanner

/// VisionKit's live text scanner, reporting the text it sees in reading order.
private struct LiveCoverScanner: UIViewControllerRepresentable {
    let onText: ([String]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onText = onText
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onText: onText) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onText: ([String]) -> Void

        init(onText: @escaping ([String]) -> Void) {
            self.onText = onText
        }

        private func report(_ items: [RecognizedItem]) {
            onText(
                items.compactMap { item in
                    if case .text(let text) = item { return text.transcript }
                    return nil
                })
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }
    }
}

// MARK: - Sample cover

/// A stand-in DVD case front, rendered to an image and read like a real photo.
private struct SampleCoverArt: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("HUGH JACKMAN   CHRISTIAN BALE")
                .font(.system(size: 14, weight: .semibold))
                .tracking(2)
            Spacer()
            Text("THE PRESTIGE")
                .font(.system(size: 40, weight: .heavy))
                .tracking(2)
                // Keep the title on one line, like a real case, so it reads as one phrase.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("ARE YOU WATCHING CLOSELY?")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
            Spacer()
            HStack {
                Text("DVD")
                    .font(.system(size: 14, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(lineWidth: 2))
                Spacer()
                Text("PG-13").font(.system(size: 14, weight: .bold))
            }
        }
        .foregroundStyle(Theme.Colors.posterTitle)
        .padding(24)
        .frame(width: 300, height: 420)
        .background(
            LinearGradient(colors: [Theme.Colors.secondary2, Theme.Colors.posterInk], startPoint: .top, endPoint: .bottom)
        )
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        ScanCoverView(appModel: appModel)
    }
    .environment(appModel)
    .environment(AppRouter())
    .task { await appModel.start() }
}
