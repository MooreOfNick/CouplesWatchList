import SwiftUI
import SwiftData

fileprivate struct UpNextEntry: Identifiable {
    let item: WatchlistItem
    let season: SeasonProgress
    let episodeNumber: Int
    var id: PersistentIdentifier { item.id }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.addedAt, order: .reverse) private var items: [WatchlistItem]

    @State private var suggestions: [TMDBSearchResult] = []
    @State private var isSuggestionsLoading = false
    @State private var selectedSuggestion: TMDBSearchResult?

    private var currentlyWatching: [WatchlistItem] {
        items.filter { $0.mediaType == .tv && $0.derivedStatus == .watching }
    }

    private var wantToWatch: [WatchlistItem] {
        items.filter { $0.mediaType == .tv && $0.derivedStatus == .wantToWatch }
    }

    private var upNext: [UpNextEntry] {
        currentlyWatching.compactMap { item in
            guard let season = item.seasonProgresses
                .filter({ $0.status == .watching })
                .sorted(by: { $0.seasonNumber < $1.seasonNumber })
                .first,
                season.episodeCount > 0 else { return nil }

            let nextEp = (1...season.episodeCount).first { !season.watchedEpisodes.contains($0) }
            guard let ep = nextEp else { return nil }
            return UpNextEntry(item: item, season: season, episodeNumber: ep)
        }
    }

    // Up to 2 currently-watching seeds + fill with recently watched, capped at 3 total.
    private var suggestionSeeds: [(id: Int, mediaType: MediaType)] {
        let watching = Array(currentlyWatching.prefix(2).map { (id: $0.tmdbID, mediaType: $0.mediaType) })
        let needed = max(0, 3 - watching.count)
        let watched = Array(
            items.filter { $0.mediaType == .tv && $0.derivedStatus == .watched }.prefix(needed)
                .map { (id: $0.tmdbID, mediaType: $0.mediaType) }
        )
        return watching + watched
    }

    private var seedIDs: [Int] { suggestionSeeds.map(\.id) }

    private var watchlistIDs: Set<String> {
        Set(items.map { "\($0.tmdbID)-\($0.mediaTypeRaw)" })
    }

    private var filteredSuggestions: [TMDBSearchResult] {
        suggestions.filter { !watchlistIDs.contains("\($0.id)-\($0.mediaType ?? "")") }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "popcorn",
                        description: Text("Search for TV shows to get started.")
                    )
                } else {
                    List {
                        if !upNext.isEmpty {
                            Section("Up Next") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(upNext) { entry in
                                            NavigationLink(destination: SeasonEpisodesView(season: entry.season, item: entry.item)) {
                                                UpNextCard(entry: entry)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                        }

                        if !currentlyWatching.isEmpty {
                            Section("Currently Watching") {
                                ForEach(currentlyWatching) { item in
                                    if !item.seasonProgresses.isEmpty {
                                        NavigationLink(destination: TVShowProgressView(item: item)) {
                                            HomeItemRow(item: item)
                                        }
                                    } else {
                                        HomeItemRow(item: item)
                                    }
                                }
                            }
                        }

                        if !wantToWatch.isEmpty {
                            Section("Want to Watch") {
                                ForEach(wantToWatch) { item in
                                    if !item.seasonProgresses.isEmpty {
                                        NavigationLink(destination: TVShowProgressView(item: item)) {
                                            HomeItemRow(item: item)
                                        }
                                    } else {
                                        HomeItemRow(item: item)
                                    }
                                }
                            }
                        }

                        if isSuggestionsLoading {
                            Section("You Might Like") {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .listRowBackground(Color.clear)
                            }
                        } else if !filteredSuggestions.isEmpty {
                            Section("You Might Like") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(filteredSuggestions) { result in
                                            SuggestionCard(result: result)
                                                .onTapGesture { selectedSuggestion = result }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .sheet(item: $selectedSuggestion) { result in
                MediaDetailView(
                    result: result,
                    isOnWatchlist: watchlistIDs.contains("\(result.id)-\(result.mediaType ?? "")"),
                    onAdd: { tvDetails, status in addToWatchlist(result, tvDetails: tvDetails, status: status) }
                )
            }
            .task(id: seedIDs) {
                guard !suggestionSeeds.isEmpty else {
                    suggestions = []
                    isSuggestionsLoading = false
                    return
                }
                isSuggestionsLoading = true
                let raw = await TMDBService.shared.fetchRecommendations(seeds: suggestionSeeds)
                guard !Task.isCancelled else { return }
                suggestions = raw
                isSuggestionsLoading = false
            }
        }
    }

    private func addToWatchlist(_ result: TMDBSearchResult, tvDetails: TMDBTVDetails?, status: WatchStatus) {
        guard let mediaType = result.resolvedMediaType else { return }
        let item = WatchlistItem(
            tmdbID: result.id,
            mediaType: mediaType,
            title: result.displayTitle,
            posterPath: result.posterPath,
            overview: result.overview ?? "",
            releaseYear: result.releaseYear,
            status: status,
            numberOfSeasons: tvDetails?.numberOfSeasons,
            numberOfEpisodes: tvDetails?.numberOfEpisodes
        )
        modelContext.insert(item)

        if let seasons = tvDetails?.seasons {
            let regularSeasons = seasons.filter { $0.seasonNumber > 0 }
            for (index, season) in regularSeasons.enumerated() {
                let progress = SeasonProgress(
                    seasonNumber: season.seasonNumber,
                    episodeCount: season.episodeCount,
                    name: season.name
                )
                switch status {
                case .watched:
                    progress.status = .watched
                case .watching:
                    progress.status = index == 0 ? .watching : .wantToWatch
                case .wantToWatch:
                    break
                }
                progress.item = item
                modelContext.insert(progress)
            }
        }
    }
}

fileprivate struct SuggestionCard: View {
    let result: TMDBSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedAsyncImage(url: result.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 3, y: 2)

            Text(result.displayTitle)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}

fileprivate struct UpNextCard: View {
    let entry: UpNextEntry

    var body: some View {
        ZStack(alignment: .bottom) {
            CachedAsyncImage(url: entry.item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.25)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.item.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text("\(entry.season.name) · Ep \(entry.episodeNumber)")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .frame(width: 120, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4, y: 2)
    }
}

struct HomeItemRow: View {
    let item: WatchlistItem

    private var watchingSeason: SeasonProgress? {
        item.seasonProgresses
            .filter { $0.status == .watching }
            .sorted { $0.seasonNumber < $1.seasonNumber }
            .first
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: item.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 48, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                if let season = watchingSeason {
                    Text("Season \(season.seasonNumber) · \(season.watchedEpisodes.count)/\(season.episodeCount) episodes watched")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        if !item.releaseYear.isEmpty {
                            Text(item.releaseYear)
                                .font(.caption)
                        }
                        if let seasons = item.numberOfSeasons {
                            Text("· \(seasons) season\(seasons == 1 ? "" : "s")")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
