# Rewind Club

An iPhone app for keeping track of the movies and shows you own on disc, own digitally, or stream: what you've watched, what you thought of it, and where the DVD actually is. When you can't decide, **Tonight** picks something from your shelf that fits the mood.

Built with SwiftUI and SwiftData, following MVVM. Everything is stored on the device, and the app works offline.

## Features

**Your shelf**
- A poster grid of everything you have: DVD, digital, or streaming, with the service it's on.
- Standard iOS search across title, director, cast, genre, year, and tags, with suggestion tokens and All / Not reviewed / Reviewed scopes.
- Filters for format, service, film rating, location, and tags.
- Sorting: A to Z, last watched, recently added, or your rating.
- Tap a poster to zoom straight into the title's details.

**Adding titles**
- **Scan a cover:** point the camera at a case, or pick a photo. The text is read on the device with Vision and matched to the catalog.
- **Import a spreadsheet:** bring in a whole collection from CSV.
- **Import from Letterboxd:** ratings, reviews, and every diary watch for films you already own.
- **Type it in:** a full form that autofills from the catalog, or takes anything entered by hand.

**For each title**
- **Watch history:** a one-tap check-off, plus every watch logged with its own date and note.
- **Reviews:** half-star ratings and notes, all collected on the Reviews tab.
- **Where it is:** Shelf, Loaned out (who has it and since when, with Mark returned), or your own places.
- **Tags:** your own, like "Christmas" or "Date night", in colors from the theme.
- **Watch trailer** and IMDb links.

**Tonight**
- Filter by mood, genre, runtime, format, tags, film rating (handy with kids), whether you've reviewed it, and your own star rating. Then **Pick one for me**.

**Profile and Settings**
- Try everything as a guest first; sign in later. Signing in keeps everything you added.
- Your streaming services, locations, and tags.
- Export your shelf as CSV, load or remove the sample movies, or delete all data.

## Requirements

- Xcode 27 or later
- iOS 27 or later, iPhone only

## Getting started

1. Clone the repo and open `MovieCollection.xcodeproj`.
2. Pick an iPhone simulator and run the **MovieCollection** scheme.

The app starts with an empty shelf. To look around with data, sign in from the Profile tab, then choose **Settings › Data › Load the sample movies**.

### Optional: live movie search (TMDB)

Without a key, the app searches a bundled catalog of 200 movies. To search The Movie Database instead:

1. Get an API Read Access Token at [themoviedb.org](https://www.themoviedb.org/settings/api).
2. Copy `Secrets.example.plist` to `MovieCollection/Resources/Secrets.plist`.
3. Paste the token into `TMDBReadAccessToken`.

`Secrets.plist` is git-ignored, so the key is never committed.

## Project structure

```
MovieCollection/
  Models/         SwiftData models (versioned schema) and value types
  Services/       Store, catalog and TMDB client, importers and exporter, CSV parsing
  ViewModels/     @Observable view models, one per screen, plus the app-wide AppViewModel
  Views/          SwiftUI screens by area (Shelf, Tonight, Add, Detail, Profile, SignIn)
    Components/   Shared building blocks: posters, tags, chips, star picker, family avatars
  Navigation/     Tab shell and per-tab navigation router
  Theme/          Colors (five brand colors plus derived tokens) and fonts
  Resources/      Fonts, sample CSVs, and (optionally) Secrets.plist
  moviedatasettest/  The bundled 200-movie catalog
MovieCollectionTests/    Unit tests (Swift Testing)
MovieCollectionUITests/  UI tests (XCUIAutomation)
docs/                    Support page and privacy policy, ready for GitHub Pages
```

### Architecture notes

- **MVVM.** Views stay thin, and each screen's state and logic lives in its view model. `AppViewModel` is the one place that changes saved data. It saves through `CollectionStore`, then refreshes, so every screen updates.
- **Versioned data.** The models are versioned with `VersionedSchema` and a `SchemaMigrationPlan`, so app updates upgrade an existing shelf instead of losing it. Version 2 added watch history, locations, and tags. See `Models/SchemaVersions.swift`.
- **Swift concurrency.** The app uses default MainActor isolation, with `@concurrent` work for loading the catalog and reading covers.
- **No accounts yet.** "Sign in" saves a profile on the device.

## Testing

```
Product › Test (⌘U)
```

The unit tests use Swift Testing, and the UI tests launch the app with `-UITesting`, which gives each run a throwaway in-memory shelf. Add `-SampleShelf` to start with the sample data.

> Test updates are paused while features are being built, so some tests are behind recent changes. See the milestone notes in `ROADMAP.md`.

## Roadmap

- **Done:** Milestones 0 to 2 (beta foundation, quick wins, and watch history with locations and tags).
- **Next:** family members, "own it instead" suggestions, then social features.

The full plan is in [ROADMAP.md](ROADMAP.md). The steps to get a beta onto TestFlight are in [TESTFLIGHT.md](TESTFLIGHT.md).

## Privacy

Everything stays on your phone. Movie search text goes to TMDB when a key is set up. Read the [privacy policy](docs/privacy.md).

## Credits

- Movie data from [The Movie Database (TMDB)](https://www.themoviedb.org). This product uses the TMDB API but is not endorsed or certified by TMDB.
- Fonts: [Caprasimo](https://fonts.google.com/specimen/Caprasimo) and [Figtree](https://fonts.google.com/specimen/Figtree), under the SIL Open Font License (see `MovieCollection/Resources/Fonts`).
