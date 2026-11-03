# Rewind Club Roadmap

Plans for the next round of features, plus what it takes to get Rewind Club onto TestFlight and the App Store. Nothing here is built yet. Each feature lists what it does, how it would work, what changes in the code, and open questions.

Effort is a rough guess: **S** is a day or less, **M** is a few days, **L** is a week or more.

---

## Contents

1. [Recommended order](#recommended-order)
2. [App Store and TestFlight readiness](#app-store-and-testflight-readiness)
3. [Feature plans](#feature-plans)
   - [Multiple watch dates](#1-multiple-watch-dates)
   - [New icon for digital copies](#2-new-icon-for-digital-copies)
   - [Trailer link](#3-trailer-link)
   - [Standard shelf search](#4-standard-shelf-search)
   - [Locations for physical copies](#5-locations-for-physical-copies)
   - [Editing locations in settings](#6-editing-locations-in-settings)
   - [Tonight filter for your star rating](#7-tonight-filter-for-your-star-rating)
   - [Shelf sorting](#8-shelf-sorting)
   - [Tags](#9-tags)
   - [Settings screen](#10-settings-screen)
   - ["Own it instead" suggestions](#11-own-it-instead-suggestions)
   - [Family members](#12-family-members)
   - [Following friends](#13-following-friends)
   - [Public or friends-only account](#14-public-or-friends-only-account)
4. [Open questions](#open-questions)
5. [Ideas parking lot](#ideas-parking-lot)

---

## Recommended order

The goal is to get a beta into testers' hands quickly, then ship improvements as TestFlight updates.

| Milestone | What's in it | Why this order |
|---|---|---|
| **0. Beta foundation** | Developer account, final bundle ID, remove the hard-coded "Ella" user, onboarding, data versioning, privacy policy, first TestFlight build | Testers can't use an app that's someone else's shelf. Data versioning must come before testers have real data. |
| **1. Quick wins** | Cloud icon, trailer link, shelf sorting, Tonight star filter, standard search, settings screen | Small, visible improvements that don't change saved data much. |
| **2. Collection depth** | Multiple watch dates, locations, tags | These change the saved data, so they're grouped into one data update. |
| **3. Family** | Family members, who has seen what, family ratings | Builds on watch history from milestone 2. |
| **4. Own it instead** | Subscription suggestions, buy links | Needs real "where to buy" data, which comes with the catalog upgrade. |
| **5. Social** | Accounts, following friends, public or friends-only | Needs a server, sign-in, and extra App Store rules. Biggest piece. |

### Milestone 1 status (October 27, 2026): built

| Feature | What was built |
|---|---|
| Cloud icon | Digital shows `icloud` (filled on poster badges), Streaming shows `tv`, DVD keeps the disc. |
| Trailer link | **Watch trailer** on the detail screen and the flip-card back opens a YouTube search for "<title> <year> official trailer". Exact trailers wait for the TMDB key. |
| Shelf sorting | Sort menu: A to Z (default, ignoring The/A/An), Last watched (never watched first, then oldest), Recently added, Your rating. Remembered between launches; the flip-card viewer follows it. |
| Tonight star filter | **Your rating**: Any, 3★ and up, 4★ and up, 4.5★ and up, Not rated. If it contradicts "Reviewed it?", the other filter adjusts and a note explains why. The old "Rating" row is now labeled "Film rating". |
| Standard search | Native iOS search on Shelf with a large "Your shelf" title. One box searches title, director, cast, genre, and year; suggestions become tokens; All / Not reviewed / Reviewed are scopes while searching. A Search button opens it (or pull the shelf down). Format, service, and film rating moved to a Filter sheet. |
| Settings | A gear on Profile opens Settings: Account, Streaming services, Data (import, **export shelf as CSV**, load or remove sample movies, delete all data), and About. |

**Not yet tested.** Tests are paused, and the old search UI test, filter tests, and the Tonight "Rating" label will need updating when tests resume.

### Milestone 2 status (November 3, 2026): built

| Feature | What was built |
|---|---|
| Data version 2 | `SchemaV2` adds `WatchEvent`, `StorageLocation`, and `Tag`. Version 1 is frozen in `Models/SchemaV1.swift`; the upgrade is a lightweight migration (`lastWatched` is renamed `legacyLastWatched`). On launch, `CollectionStore.upgradeLegacyData()` turns each old date into the first watch and puts every DVD on the Shelf. Checked on the simulator's existing version 1 shelf. |
| Multiple watch dates | The detail screen's Watched check is still one tap, and below it the watch history lists "3rd watch · Oct 21, 2026" rows, newest first. Tap a watch to change its date or note, or delete it. **Log another watch** adds one. Unchecking with several watches asks first. Future dates aren't allowed. The flip-card back and detail show "Last watched … · 3 times". Letterboxd diary imports bring in every logged watch. |
| Locations | DVDs get **Where it is**: Shelf, Loaned out (who has it and since when), or a custom place. It's in the add and edit forms, and on the detail screen with **Move** and **Mark returned** (back to where it was). The detail screen's old "Location:" label is now "Format:". The filter sheet has a "Where it is" filter. |
| Editing locations | **Settings › Organizing › Locations**: add, tap to rename, drag to reorder, swipe to delete (discs move to Shelf after a confirmation). Shelf and Loaned out can be renamed but not deleted. Settings also lists what's loaned out right now. |
| Tags | Tags as colored chips on the detail screen, flip-card back, and forms, chosen in a tag picker that can also make new ones. Names are unique, ignoring capitals. Filter by tags on the Shelf (filter sheet, search text, and "Tag:" search tokens) and on Tonight. **Settings › Organizing › Tags**: add, rename, recolor, merge, delete. |
| Import and export | The CSV export adds Where, Times Watched, and Tags columns. The spreadsheet import reads Where and Tags back, making new locations and tags as needed. |

**Still open:** whether Tonight's "Rewatch" should mean "watched before" instead of "reviewed" (unchanged for now). **Tests are out of date** where they set `lastWatched` directly, call `updateLocation`, or check the Letterboxd watch date; catch these up when tests resume.

Milestones 0 and 1 together are the fastest path to a useful beta. Social features can wait for a later beta, and they bring the most App Store review requirements.

---

## App Store and TestFlight readiness

### Milestone 0 status (October 27, 2026)

All the code work is done. What's left needs your Apple and TMDB accounts. Follow **[TESTFLIGHT.md](TESTFLIGHT.md)** step by step.

**On hold (Oct 27):** the TMDB key and deployment steps wait until closer to beta. TMDB asks for a hosted app or website before issuing a key. Until then the app uses the bundled 200 movies, and everything else works without the key.

| Item | Status |
|---|---|
| Developer account | **To do (you):** join the program and pick your team in Signing & Capabilities. |
| Bundle ID | **Decided:** keeping `brownk1.MovieCollection`. |
| Replace hard-coded Ella | **Done.** First launch is empty, with no sample data and no sign-in. Guests use Shelf, Add, Tonight, and Reviews with their own movies, and empty states point them to Add. Profile and Friends show a sign-in page instead (name and photo, then services). Signing in keeps everything they already added. Signed-in users can load or remove the sample movies in Profile › About. Friends is labeled "coming soon". "Sign in" currently saves the profile on the phone only; real accounts that back up and sync come with Milestone 5. |
| Data versioning | **Done.** `SchemaV1` and `RewindClubMigrationPlan` in `Models/SchemaVersions.swift`. Every store goes through `CollectionStore.makeContainer`. |
| Movie data | **Done in code. Needs your key.** Live TMDB search in the add form, cover scanner, and spreadsheet import, with the bundled 200 movies as the offline fallback. The TMDB credit is on the Add tab and in Profile › About. **To do (you):** TESTFLIGHT.md step 2. |
| Privacy policy and support page | **Written:** `docs/privacy.md` and `docs/index.md`, ready for GitHub Pages. **To do (you):** host them, then set `AppInfo.privacyPolicyURL` (TESTFLIGHT.md step 3). |
| Feedback link | **Done in code.** "Send feedback" appears in Profile › About once `AppInfo.feedbackEmail` is set. |
| Export compliance | **Done.** `ITSAppUsesNonExemptEncryption = NO`. |
| Privacy manifest | **Done.** `PrivacyInfo.xcprivacy` declares the UserDefaults reason (CA92.1) and no tracking. |
| iPhone only | **Done.** `TARGETED_DEVICE_FAMILY = 1`. "Designed for iPhone" on Mac and Vision Pro is turned off. |
| App category | **Done.** Entertainment. |
| Formatter cleanup | **Done.** `.swift-format` matches the project's 4-space style; all 249 style issues fixed. |
| TestFlight text | **Written:** the beta description and "What to Test" are in TESTFLIGHT.md. |
| First TestFlight upload | **To do (you):** TESTFLIGHT.md steps 4–6. |
| Tests | **Paused** while features are built. The guest and sign-in changes are covered by the last test run. |

### Things that block the first TestFlight build

1. **Join the Apple Developer Program.** It costs $99 a year. In Xcode, sign in under Settings › Accounts, then pick your team under the target's Signing & Capabilities.

2. **Choose the final bundle ID before the first upload.** It's currently `brownk1.MovieCollection`. An App Store app record is tied to its bundle ID forever, so pick the real one now, for example `com.kyleebrown.rewindclub`. The project and target can keep the name "MovieCollection". Only the bundle ID and display name matter to users.

3. **Replace the hard-coded "Ella Lauren" user.** Right now every tester would see Ella's photo, name, and 30 seeded movies.
   - Add a short onboarding flow covering your name, an optional photo, and which streaming services you pay for. The services part reuses the new subscriptions sheet.
   - Start with an empty shelf, plus a "Load a sample shelf" option for people who want to look around. The seeder already exists. It just needs to become opt-in.
   - Hide or label the sample Friends reviews, for example "Coming soon", until social features exist.
   - Code changes:
     - `UserProfile.ella` becomes a saved, editable profile.
     - `ShelfSeeder` runs only on request.
     - `ProfileView` reads the saved profile.

4. **Version the saved data before testers have any.** SwiftData can upgrade data between app versions if the models are versioned.
   - Wrap the current models in a `VersionedSchema` (version 1) and add a `SchemaMigrationPlan`.
   - Milestone 2 then becomes version 2 with a planned migration, for example turning each existing `lastWatched` into the first watch event.
   - Without this, a later update could wipe or crash testers' shelves.

5. **Check the movie data license.**
   - The 200-movie catalog comes from a Kaggle dataset built from TMDB (The Movie Database) data. TMDB's terms require attribution, and commercial use needs approval.
   - For a beta, the safest path is to switch the catalog to the TMDB API with the required credit line: "This product uses the TMDB API but is not endorsed or certified by TMDB." See [the catalog note](#a-note-on-the-catalog).
   - The film ratings (G, PG, PG-13, and so on) in the current file were filled in by hand. TMDB's certification data should replace them.

6. **Write a privacy policy and host it at a URL.** Every app needs one, even one that collects nothing. For the beta:
   - Everything is stored only on the device.
   - The camera is used only to read case text on the phone.
   - Nothing is sent anywhere.
   - That changes once social features or the TMDB API arrive, so update the policy then.

7. **Add the export compliance key.** Add `ITSAppUsesNonExemptEncryption = NO` to the Info.plist. Otherwise App Store Connect asks about encryption on every upload.

8. **Decide on iPhone only, or iPhone and iPad.** The target currently includes iPad, which is device family 1 and 2.
   - Either make it iPhone-only for the beta, or test the layouts on iPad first.
   - iPhone-only is faster. iPad can come later.

### Uploading a beta

1. Create the app in App Store Connect under My Apps, then the plus button. Use the final bundle ID and the name "Rewind Club". Check that the name is available, since App Store names must be unique.
2. In Xcode, choose "Any iOS Device" as the destination. Then choose Product › Archive, then Distribute App › App Store Connect › Upload.
3. **Internal testing.** You can invite up to 100 people on your App Store Connect team with no review. It's best for the first round.
4. **External testing.** You can invite up to 10,000 people with a public link. The first build needs a quick Beta App Review, usually about a day. Fill in the beta description, what to test, and a feedback email.
5. TestFlight builds expire after 90 days, so plan to upload updates regularly.
6. **Optional: Xcode Cloud.** It can build, test, and upload to TestFlight automatically on each push.

### Nice to have before beta

- ~~**An in-app feedback link.**~~ Done; set `AppInfo.feedbackEmail` to turn it on.
- **Tests on Command-U.** Add both test targets to the main scheme and set the unit tests' Host Application in Xcode. Then Command-U runs every test.
- ~~**Formatter cleanup.**~~ Done.
- **A real-device check.** See TESTFLIGHT.md step 7.

### Before public App Store release, not needed for TestFlight

- **Screenshots** at the currently required iPhone sizes, plus an app description, keywords, support URL, and marketing URL.
- **The age rating questionnaire.** Social features with posted content can raise the age rating.
- **App Privacy labels.** These are the "nutrition label" in App Store Connect, and they must match what the app really collects.
- **If social features ship,** the [social requirements](#app-store-rules-for-social-features) apply.

---

## Feature plans

### 1. Multiple watch dates

**Goal.** Log every time a title is watched: 1st watch, 2nd watch, and so on, each with its own date.

**How it works**
- The detail screen's "Watched" check becomes a **Watch history** section:
  - It lists "1st watch · Sep 25, 2024", "2nd watch · Oct 21, 2026", and so on, newest first.
  - **Log a watch** adds one, with a date picker that defaults to today.
  - Swipe or tap a watch to edit or delete it.
  - The first tap on an unwatched title still works as a one-tap check-off.
- The shelf card and flip-card back show the latest watch, plus a count like "Watched 3 times".
- Letterboxd diary imports can bring in every logged watch, not just the latest. Diary rows already mark rewatches.

**Data changes**
- **A new `WatchEvent` model** stores a date and an optional note, with a link to its title. Deleting a title deletes its watches.
- **Watch info becomes calculated.** `OwnedTitle.lastWatched` becomes the newest watch event, and a new `watchCount` counts them.
- **Existing data upgrades.** The migration turns each existing `lastWatched` into one watch event.
- **Ready for family.** A watch event can later record which family members were there.

**Code touch points**
- **Detail screen.** `TitleDetailViewModel.setWatched` changes, and the detail screen gets a watch history list.
- **Progress bar.** `AppViewModel.watchedCount` stays the same, since a title counts once it has any watches.
- **Tonight.** "Rewatch" could mean "watched before" instead of "reviewed". This is worth deciding.

**Edge cases.** Unchecking Watched on a title with several watches asks "Remove all 3 watches?" first. Dates in the future aren't allowed.

**Tests.** Ordinal labels (1st, 2nd, 3rd, 11th, 21st), latest-date calculation, migration from one date, and Letterboxd diary import.

**Effort: M**

---

### 2. New icon for digital copies

**Problem.** The download arrow on "Digital" looks like a button that downloads or plays the movie.

**Options**

| Icon (SF Symbol) | Reads as | Notes |
|---|---|---|
| `icloud` (recommended) | "In the cloud" | Familiar and passive. Matches your idea. |
| `cloud.fill` | Same, bolder | Better at small badge sizes on posters. |
| `externaldrive.badge.icloud` | "Stored online" | More literal, but busy at small sizes. |
| `square.stack` | "In your library" | Neutral, but less clearly "digital". |

**Recommendation.** Use `icloud` on tags and `cloud.fill` on small poster badges.

**Also consider changing the streaming icon.** The current cast icon, `airplayvideo`, has the same problem, since it looks like you can play to a TV. Options:
- `tv` is a TV screen.
- `play.tv` is less passive.
- `antenna.radiowaves.left.and.right` means a service.

The DVD disc icon is fine, since it already reads as a thing you own.

**Code change.** This is one line per format in `MediaFormat.systemImage`, in `Views/Components/Tags.swift`.

**Effort: S**

---

### 3. Trailer link

**Goal.** A **Watch trailer** button on the detail screen and the flip-card back, since your family loves trailers.

**How it works**
- **Now, with no API needed.** The button opens a YouTube search for "<title> <year> official trailer". It works for every title, including hand-entered ones.
- **Later, with the TMDB catalog.** TMDB's videos endpoint gives the exact official trailer for each movie, so the button can open that video directly.
- The link opens in the YouTube app if it's installed, otherwise in Safari.
- **Optional extra.** An in-app player using `SafariViewController`, so viewers stay in Rewind Club, plus a "Trailer night" mode on Tonight that queues trailers for the matching movies.

**Code changes**
- Add `TitleDisplay.trailerURL(title:year:)`, next to the existing `imdbURL`.
- Add a button next to the IMDb link.

**Effort: S**, or **M** with the TMDB exact-trailer version.

---

### 4. Standard shelf search

**Goal.** Make search work the way people expect from iOS apps.

**Today.** Tapping the fake search bar opens a big custom panel that mixes search text and every filter.

**Proposed**
- **A real search field.** Tap it and start typing right on the shelf. It has a clear button, a Cancel button, and the keyboard's Search key, and results update live in the grid.
- **One search box for everything.** Typing searches title, director, cast, genres, and tags at once. No separate Actor, Director, and Year boxes are needed.
- **Suggestions while typing.** For example "Director: Christopher Nolan" or "Genre: Comedy". Tapping one turns it into a search token, a chip inside the field, which is the standard iOS pattern.
- **Filters move to a separate Filter button** with a count badge, next to the search field. It opens a sheet with format, service, rating, location, and tags.
- **Review chips become search scopes.** All, Not reviewed, and Reviewed become the standard segmented scope bar under the field.
- **"No results" uses Apple's built-in search empty state,** with a "Clear filters" button.
- **Recent searches** are optional.

**Design choice to make.** SwiftUI's built-in `.searchable` needs the system navigation bar, which the app currently hides for the custom headers.
- **Option A, native.** Show the system bar on the Shelf only, with a large "Your shelf" title and `.searchable`. It's the most "standard", and you get scopes, tokens, and suggestions for free.
- **Option B, custom.** Keep the custom header, but make the search field real and inline with the same behaviors. It matches the current design more closely.
- **Recommendation: Option A,** because it's closest to iOS best practices and less code to maintain.

**Code changes**
- The search panel in `ShelfSearchOverlay.swift` is mostly replaced.
- `ShelfViewModel.Filters` simplifies to one query, tokens, and filter-sheet settings.

**Effort: M**

---

### 5. Locations for physical copies

**Goal.** For DVDs and Blu-rays, track where the disc physically is. "Shelf" and "Loaned out" come built in, and you can add your own, like "Living room cabinet" or "Grandma's house".

**How it works**
- **Edit and add forms.** Physical copies get a **Location** picker: Shelf, Loaned out, and any custom locations.
- **Loaned out details.** Choosing **Loaned out** asks who has it, either a typed name or a family member, and since when. The detail screen then shows "Loaned to Sam since Oct 3". A **Mark returned** button moves it back to its previous location.
- **Showing the location.** The detail screen and flip-card back show it, for example "Location: Living room cabinet".
- **Filtering.** The shelf filter sheet gets a Location filter. One useful view is "what's loaned out right now".

**Data changes**
- **A new `StorageLocation` model** stores a name, a sort order, and whether it's built in, either Shelf or Loaned out.
- **Title links.** An `OwnedTitle` gets a location for DVDs, a loaned-to name, and a loaned-on date.
- **Existing data upgrades.** The migration sets every existing DVD to "Shelf".

**Naming conflict to fix.** The detail screen already uses "Location:" for how you own it, like "Owned · DVD". That label should become **"Format:"** or **"How you have it:"**, so "Location" can mean the physical place.

**Effort: M**

---

### 6. Editing locations in settings

**How it works.** **Settings › Locations** lists every location.
- **Add** a location with a name.
- **Rename** a location by tapping it.
- **Reorder** locations by dragging.
- **Delete** a location by swiping. Discs stored there move back to "Shelf", after a confirmation like "3 discs will move to Shelf".
- "Shelf" and "Loaned out" can be renamed but not deleted, since they're the defaults the app relies on.

**Effort: S**, once location data from feature 5 exists.

---

### 7. Tonight filter for your star rating

**Goal.** Filter Tonight's picks by your own star rating, for example "only movies I rated 4 stars or more".

**How it works**
- A new **Your rating** row of chips with these options: **Any**, **3★ and up**, **4★ and up**, **4.5★ and up**, and **Not rated**.
- Choosing a star level only makes sense for reviewed titles. If "Reviewed it?" is set to "Not reviewed yet", the app switches it to "Anything" and shows a short note, so the filters don't cancel each other out.
- Today the "Rewatch" option means "reviewed". With feature 1, it can mean "watched before", which pairs nicely with this filter.

**Code changes**
- Add `TonightViewModel.minimumRating` and include it in `fits(_:)`.
- Add one more chip group in `TonightView`.

**Effort: S**

---

### 8. Shelf sorting

**Goal.** A sort menu on the Shelf.

**Sort options**

| Sort | Order | Notes |
|---|---|---|
| **A to Z** (default) | Title order, ignoring "The", "A", and "An" | So "The Matrix" sorts under M. |
| **Last watched** | Longest since you watched it first | Great for finding rewatch ideas. |
| Recently added | Newest first | Optional extra. |
| Your rating | Highest first | Optional extra. |

**Undecided: never-watched titles in "Last watched".** Do they go first, since it's been "forever", or at the end? A third option is a separate "Never watched" group at the top. Recommendation: a "Never watched" group first, then oldest watch first. See the [open questions](#open-questions).

**How it works**
- A **Sort** button next to the search field opens a menu with a checkmark on the current choice.
- The choice is remembered between launches.
- The current sort shows subtly, for example "Sorted by last watched".
- The flip-card viewer follows the same order.

**Code changes**
- Add a `ShelfViewModel.sortOrder` enum, saved with `@AppStorage`.
- `visibleTitles` sorts after filtering.

**Effort: S**

---

### 9. Tags

**Goal.** Make your own tags, like "Christmas", "Comfort movie", "Date night", or "Kids' favorites", and put any number on each title.

**How it works**
- **Adding tags.** The detail screen shows a title's tags as chips. **Add tag** picks existing tags or creates a new one inline. The edit and add forms get the same picker.
- **Filtering.** The shelf filter sheet and search tokens filter by tag. Tonight gets an optional Tags row too, like "something from Date night".
- **Managing tags.** **Settings › Tags** lists every tag with how many titles use it. You can rename, recolor, delete, or merge two tags into one.

**Data changes**
- **A new `Tag` model** stores a name and a color picked from the theme palette.
- **Many tags per title.** Each title can have many tags, and each tag many titles.
- **Unique names.** Tag names are unique, ignoring capitals, so "christmas" and "Christmas" are the same tag.

**Tests.** Creating, renaming, merging, deleting a tag that's in use, filtering by tag, and that tag names are unique.

**Effort: M**

---

### 10. Settings screen

Profile is filling up, so settings get their own screen. A gear button on Profile opens a **Settings** screen with these sections:

| Section | Contents | Feature |
|---|---|---|
| Account | Name, photo, public or friends-only | onboarding, 14 |
| Streaming services | The existing subscriptions sheet | done |
| Locations | Manage locations | 6 |
| Tags | Manage tags | 9 |
| Family | Manage family members | 12 |
| Suggestions | "Suggest ways to own subscription movies" toggle | 11 |
| Data | Import, export your collection as CSV, delete all data | export is new |
| About | Privacy policy, send feedback, TMDB credit, version | App Store |

Simple on and off choices are saved with `@AppStorage`. Lists like locations, tags, and family are saved with SwiftData.

**Effort: S** for the screen, with each section counted in its own feature.

---

### 11. "Own it instead" suggestions

**Goal.** For movies you only have through a subscription, suggest ways to own it, so you can eventually drop subscriptions. It's on by default, with a toggle in Settings.

**How it works.** On the detail screen of a **Streaming** title, a card titled "Own it instead" shows:
- **Search eBay** opens an eBay search for "<title> <year> DVD Blu-ray".
- **Buy digitally** links to where it's sold digitally, such as Apple TV, Amazon, or Fandango at Home.
- If the movie can't be bought anywhere, which is common for streaming originals, it says **"No way to own this yet."**

**Where the data comes from**
- **The simple version.** Always show eBay and store search links. It works today, but it can't know when something is streaming-only.
- **The accurate version.** TMDB's "watch providers" data, which comes from JustWatch, lists per country where a movie can be streamed, rented, or bought. If there are no "buy" options, the card shows "No way to own this". It needs the TMDB catalog upgrade. TMDB requires crediting JustWatch for this data.
- **Region.** Use the user's country, starting with the US.

**Possible later extras**
- **Affiliate links,** through the eBay Partner Network or Amazon Associates. This could earn a little money, but it needs a disclosure in the app.
- **A "Subscription check-up" screen.** It lists each subscription with how many of your movies depend on it. This helps decide which service to cancel.

**Effort: S** for the simple version, **M** for the accurate version with TMDB.

---

### 12. Family members

**Goal.** Add up to 15 family members, each with a name and age. You can then see who has seen each movie, when they last watched it, and their own star rating. This is just for you. Family members don't have accounts, and nothing is shared.

**How it works**
- **Settings › Family.** Add, edit, or remove family members, up to 15. Each gets a name, an age, and a color for their avatar circle.
- **A Family section on the detail screen** has one row per member:
  - Seen or not seen, with a quick check.
  - Their last watch date.
  - Their own half-star rating, using the existing star picker.
- **Logging a watch** (feature 1) can tick who was there, which updates everyone at once.
- **Shelf filter: "Not seen by".** Pick one or more family members to find what they haven't seen.
- **Tonight: "Who's watching?"** Tap the family members on the couch to show only movies none of them have seen, or ones most of them haven't.
  - It can also suggest a rating cap from the youngest viewer's age, for example under 13 suggests G and PG. You can turn that suggestion off.
- **Detail screen summary,** such as "Not seen by: Sam, Riley".

**Data changes**
- **A new `FamilyMember` model** stores a name, an age, a color, and a sort order. The app enforces the limit of 15.
- **A watch event records** which members were there.
- **A new `FamilyRating` model** links a member, a title, and a rating.
- **Deleting a member** removes their ratings and their place in past watches, after a confirmation.

**Privacy.** Family names and ages, which may include children, should stay **on the device only**, even after social features exist. That keeps the app clear of children's data rules and is simpler to explain in the privacy policy.

**Effort: L**

---

### 13. Following friends

**Goal.** Follow real friends and see what they're watching and reviewing. This replaces today's sample Friends screen.

**What it needs.** This is the first feature that needs a **server and accounts**. Everything before it works on the device alone.

| Option | Good | Watch out for |
|---|---|---|
| **CloudKit** (Apple) | No server to run, cheap or free at small scale, uses the person's iCloud, Apple handles security | Apple devices only. Public search and following need careful design in CloudKit's public database. |
| **Supabase** or **Firebase** | Full control, easy search, works on Android and the web later | Another service to run and pay for. You handle sign-in, security rules, and moderation tools. |

**Recommendation.** Start with **CloudKit plus Sign in with Apple** for the beta, since it's iPhone-only and cheapest to run. Choose Supabase if an Android version or website is likely soon.

**How it works**
- **A profile handle,** like @kylee, made during onboarding when social features ship.
- **Finding people.** Search for people. Only public accounts appear in search (see feature 14). You can also share an invite link.
- **Following.** Follow and unfollow. Following a friends-only account sends a request, and they approve or decline.
- **A Friends feed** shows reviews and ratings from people you follow, newest first, using the existing friend review cards.
- **Choosing what you share,** like reviews, ratings, and your shelf, plus "currently watching" if wanted. Family data is **never** shared.

#### App Store rules for social features

- **Guideline 1.2, user-generated content.** Apps where people post content must have:
  - A way to **report** content.
  - A way to **block** people.
  - A way to filter objectionable content.
  - Published contact info.
- **Guideline 5.1.1(v), account deletion.** If people can make an account, they must be able to **delete it from inside the app**.
- **Guideline 4.8, Sign in with Apple.** If you offer Google or other social sign-in, you must also offer Sign in with Apple or an equivalent private sign-in.
- **Privacy.** The privacy policy and App Privacy labels must be updated for account data and shared reviews.

**Effort: L**, the largest feature in this plan.

---

### 14. Public or friends-only account

**Goal.** Control who can find you and see your stuff.

| Setting | Searchable | Who can see your reviews and shelf |
|---|---|---|
| **Public** | Yes | Anyone |
| **Friends only** (recommended default) | No | Only people you've approved |

**How it works**
- **The toggle lives in Settings › Account.**
- **Switching to Friends only** hides you from search right away. It also hides your content from anyone you haven't approved.
- **Switching from Public to Friends only** asks whether to keep current followers or review them.
- **Your profile shows a small badge** for which mode you're in.

**Default.** Friends only is safest and simplest to explain. People can opt in to Public.

**Effort: M**, as part of feature 13.

---

### A note on the catalog

Several features work much better with real movie data from the TMDB API instead of the bundled 200-movie file:
- Exact trailers.
- Where to buy or stream.
- Official film ratings.
- Posters, which could replace the letter tiles if wanted.
- Any movie, not just 200.

**What the upgrade involves:**
- A free TMDB API key.
- The required credit in About.
- Saving results on the device, so the app works offline.

Keeping a small bundled catalog as an offline fallback is a good idea.

**Effort: M**

---

## Open questions

1. ~~**Last-watched sort.**~~ Decided: never-watched titles first, then the longest since watching.
2. **"Rewatch" on Tonight.** Should it mean "reviewed" as it does today, or "watched before", once watch history exists?
3. **Loaned out.** Track who has it and since when? Add a reminder to ask for it back?
4. ~~**Search style.**~~ Decided: native iOS search with the system navigation bar on Shelf.
5. **Family ages.** Use the youngest viewer's age to suggest film ratings on Tonight, or just store the ages?
6. **Social server.** CloudKit for iPhone-only (recommended), or Supabase or Firebase if Android or a website is planned?
7. **Account default.** Friends only (recommended) or Public?
8. ~~**Beta catalog.**~~ Decided: switch to the TMDB API in Milestone 0, with the bundled 200 movies as the offline fallback.
9. **Developer account.** Do you already have an Apple Developer Program membership? (Bundle ID decided: keep `brownk1.MovieCollection`.)
10. ~~**Devices.**~~ Decided: iPhone only for the beta.
11. **Buy-link region.** US only to start, or the user's country?

---

## Ideas parking lot

More ideas to add here later:

-
