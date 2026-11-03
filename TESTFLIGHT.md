# Getting Rewind Club onto TestFlight

Everything in the code is ready. These steps need your Apple account, so they're yours to do, roughly in this order.

## 1. One-time setup

1. **Join the Apple Developer Program** at developer.apple.com/programs ($99 a year). Approval can take a day or two.
2. **Sign in to Xcode** under Xcode › Settings › Accounts, using the same Apple Account.
3. **Pick your team.** Select the MovieCollection target, open Signing & Capabilities, and choose your team. Leave "Automatically manage signing" on. The bundle ID stays `brownk1.MovieCollection`.

## 2. Add the TMDB key

1. Create a free account at themoviedb.org. Under Settings › API, request an API key; "Developer" use is fine for a beta.
2. Copy `Secrets.example.plist` (in the project folder) to `MovieCollection/Resources/Secrets.plist`.
3. Paste the **API Read Access Token** into `TMDBReadAccessToken`.
4. Run the app and search for a movie that isn't in the built-in 200 to confirm it works.

`Secrets.plist` is git-ignored, so the key won't be committed. It is bundled inside the app, which is normal for TMDB keys. If the app will ever make money, ask TMDB for commercial approval first.

## 3. Publish the privacy policy and support page

App Store Connect needs a privacy policy URL before external testers can install the app.

1. Create a GitHub repository and push this project to it.
2. In the repository, open Settings › Pages and set the source to **Deploy from a branch**, branch `main`, folder `/docs`.
3. After a minute, the pages are live:
   - Support: `https://<your-username>.github.io/<repo-name>/`
   - Privacy: `https://<your-username>.github.io/<repo-name>/privacy`
4. In `MovieCollection/Models/AppInfo.swift`, set:
   - `privacyPolicyURL` to the privacy URL.
   - `feedbackEmail` to the address you want feedback sent to.

   Both links appear in Profile › About once they're set.

Any static host works if you'd rather not use GitHub; the pages are in `docs/`.

## 4. Create the app in App Store Connect

1. Go to appstoreconnect.apple.com › Apps › **+** › New App.
2. Fill in:
   - **Platform:** iOS
   - **Name:** Rewind Club (it must be unique on the App Store; try a variation if it's taken)
   - **Primary language:** English (U.S.)
   - **Bundle ID:** `brownk1.MovieCollection`
   - **SKU:** anything, for example `rewindclub-001`
3. Under App Information, set the category to **Entertainment** and add the privacy policy URL.

## 5. Upload a build

1. In Xcode, set the run destination to **Any iOS Device (arm64)**.
2. Choose Product › Archive.
3. In the Organizer that opens, choose Distribute App › App Store Connect › Distribute.
4. After about 10–30 minutes of processing, the build appears under the app's TestFlight tab.

**Before every later upload**, raise the build number: target › General › Identity › Build, from 1 to 2, 3, and so on. App Store Connect rejects a repeated build number. Raise the version (1.0 → 1.1) only for bigger releases.

Export compliance is already answered in the app (`ITSAppUsesNonExemptEncryption = NO`), so it won't ask.

## 6. Invite testers

- **Internal testers** (up to 100 people on your App Store Connect team): Users and Access › add them, then TestFlight › Internal Testing › add them to a group. No review needed.
- **External testers** (up to 10,000 people): TestFlight › External Testing › create a group, add the build, and submit it for Beta App Review (usually about a day). You can then share a public link.

TestFlight builds expire after 90 days.

### Text for the TestFlight pages

**Beta App Description**

> Rewind Club keeps track of the movies and shows you own on disc, own digitally, or stream. Add titles by scanning a case, importing a spreadsheet or Letterboxd export, or typing them in. Check off what you've watched, rate and review it, and let Tonight pick something that fits the mood. Everything is saved on your phone.

**What to Test**

> Thanks for trying Rewind Club! The app starts with an empty shelf, so please use it with your own movies.
>
> - Add a few titles each way: scan a DVD or Blu-ray case, type one in, or import a spreadsheet.
> - Open a title and check off Watched and Reviewed, then rate it.
> - Flip through your shelf, and try search and filters.
> - Use Tonight to pick a movie.
> - Sign in from the Profile tab and set your streaming services.
>
> Anything confusing, broken, or missing? Take a screenshot and tap Share Beta Feedback.

**Feedback email:** the same address as `AppInfo.feedbackEmail`.

**Sign-in for review:** no account is needed. Tell the reviewer: "No login required; Profile › Sign in only asks for a name."

## 7. Check on a real iPhone first

The simulator can't test everything. On a real iPhone, check:

- Live cover scanning with the camera.
- The tab bar hiding while the keyboard is up.
- Picking a profile photo.
- TMDB search on cellular data and offline.

## Requirements to know

- The app requires **iOS 27** (the deployment target). Testers on older iOS versions can't install it. Lower `IPHONEOS_DEPLOYMENT_TARGET` if that's a problem; some newer APIs may then need availability checks.
- iPhone only. It won't appear on iPad, Mac, or Vision Pro.
