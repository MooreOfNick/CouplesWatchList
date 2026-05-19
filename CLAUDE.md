# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Couples Watch List** is an iOS app for tracking movies and TV shows together. It uses SwiftUI + SwiftData for the UI and persistence, and the TMDB API for search and metadata.

- **Platform**: iOS (portrait-only for iPhone; landscape supported on iPad)
- **Minimum deployment target**: iOS 26.0
- **Language**: Swift 5.0
- **Frameworks**: SwiftUI, SwiftData (no third-party dependencies)

## Build & Run

This is an Xcode project with no Swift Package Manager dependencies. Build and run via Xcode or `xcodebuild`:

```bash
# Build for simulator
xcodebuild -project "Couples Watch List.xcodeproj" \
  -scheme "Couples Watch List" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build

# Run tests (if a test target exists)
xcodebuild -project "Couples Watch List.xcodeproj" \
  -scheme "Couples Watch List" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  test
```

### API Key Setup

The TMDB API key is read from `Couples Watch List/Secrets.plist` (gitignored). Create this file with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>TMDB_API_KEY</key>
    <string>YOUR_API_KEY_HERE</string>
</dict>
</plist>
```

Without this file, search will fail with a `missingAPIKey` error (gracefully surfaced in the UI).

## Architecture

### Data Layer (`Item.swift`)

Two SwiftData `@Model` classes form the entire persistence layer:

- **`WatchlistItem`** — a movie or TV show. Stores `tmdbID`, `mediaTypeRaw`, `title`, `posterPath`, `overview`, `releaseYear`, `statusRaw`, `numberOfSeasons`, `numberOfEpisodes`, and a cascade-delete relationship to `[SeasonProgress]`.
- **`SeasonProgress`** — per-season tracking for TV shows. Stores `seasonNumber`, `episodeCount`, `name`, `statusRaw`, `currentEpisode`, and `watchedEpisodes: [Int]` (a list of watched episode numbers, not a bitmask).

**Enum storage pattern**: SwiftData doesn't support `Codable` enums as stored properties, so both models store enums as raw `String` (`statusRaw`, `mediaTypeRaw`) with computed property wrappers (`status`, `mediaType`).

**Derived status**: `WatchlistItem.derivedStatus` computes the overall watch status from season-level statuses for TV shows, and falls back to the stored `status` for movies (or when no season data exists). Always use `derivedStatus` when displaying or filtering a TV show's status — not `status` directly.

### Networking (`Networking/`)

- **`TMDBService`** — a Swift `actor` singleton (`TMDBService.shared`). Two methods: `searchMulti(query:)` and `fetchTVDetails(id:)`. All calls must use `await`. Returns only `movie` and `tv` results (filters out `person` results from the multi-search endpoint). Poster images are fetched via `https://image.tmdb.org/t/p/w500{path}`.
- **`TMDBModels.swift`** — `Codable` structs mirroring TMDB JSON. `TMDBSearchResult` handles both movie (`title`, `releaseDate`) and TV (`name`, `firstAirDate`) via optional fields with computed `displayTitle` and `releaseYear` helpers.

### View Layer (`Views/`)

The app has a 3-tab structure defined in `ContentView`:

| Tab | View | Responsibility |
|-----|------|----------------|
| Home | `HomeView` | "Up Next" horizontal scroll + "Currently Watching" / "Want to Watch" sections |
| Watchlist | `WatchlistView` | Full list with filter menu (by `WatchStatus` and `MediaType`) |
| Search | `SearchView` | Debounced TMDB search; opens `MediaDetailView` sheet on tap |

**Navigation flow for TV shows**: `SearchView` → (sheet) `MediaDetailView` → (dismiss, added to list) → `WatchlistView` or `HomeView` → `TVShowProgressView` (season list) → `SeasonEpisodesView` (episode checklist).

### ViewModel (`ViewModels/SearchViewModel.swift`)

`SearchViewModel` is `@Observable` (not `ObservableObject`). It debounces search by 350 ms using `Task.sleep` and cancels the previous `Task` on each new keystroke. The view binds `.onChange(of: viewModel.query)` to trigger `viewModel.search()`.

### Key Behaviors to Preserve

- **Auto-advance seasons**: In `SeasonEpisodesView`, marking the last episode of a season as watched automatically sets the next season's status to `.watching` (if it was `.wantToWatch`). This is done in `advanceToNextSeason()`.
- **Season status → episode sync**: Setting a season to `.watched` via the menu fills `watchedEpisodes` with all episode numbers; setting to `.wantToWatch` clears it.
- **Add-to-watchlist season initialization**: When a TV show is added, `SearchView.addToWatchlist` creates `SeasonProgress` entries for all regular seasons (season number > 0, filtering out specials). The initial statuses mirror the chosen `WatchStatus`: all watched → all `.watched`; watching → first season `.watching`, rest `.wantToWatch`; want to watch → all `.wantToWatch`.
- **`WatchlistRowView` vs TV shows**: Movies get an inline `Picker` for status; TV shows with season data display `derivedStatus` as read-only text (status is managed at the season level).
