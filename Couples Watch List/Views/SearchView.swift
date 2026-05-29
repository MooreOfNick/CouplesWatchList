import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var watchlist: [WatchlistItem]

    @State private var viewModel = SearchViewModel()
    @State private var selectedResult: TMDBSearchResult?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.query.isEmpty {
                    TrendingGridView(
                        results: viewModel.trendingResults,
                        isLoading: viewModel.isTrendingLoading,
                        isOnWatchlist: isOnWatchlist,
                        onSelect: { selectedResult = $0 }
                    )
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Movies & TV shows")
            .onChange(of: viewModel.query) { viewModel.search() }
            .task { await viewModel.loadTrending() }
            .sheet(item: $selectedResult) { result in
                MediaDetailView(
                    result: result,
                    isOnWatchlist: isOnWatchlist(result),
                    onAdd: { tvDetails, status in addToWatchlist(result, tvDetails: tvDetails, status: status) }
                )
            }
        }
    }

    private var searchResultsList: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            } else {
                ForEach(viewModel.results) { result in
                    SearchResultRow(result: result, isOnWatchlist: isOnWatchlist(result))
                        .contentShape(Rectangle())
                        .onTapGesture { selectedResult = result }
                }
            }
        }
        .listStyle(.plain)
    }

    private var watchlistIDs: Set<String> {
        Set(watchlist.map { "\($0.tmdbID)-\($0.mediaTypeRaw)" })
    }

    private func isOnWatchlist(_ result: TMDBSearchResult) -> Bool {
        watchlistIDs.contains("\(result.id)-\(result.mediaType ?? "")")
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
                // Mirror the chosen status: all seasons watched, first season watching, rest want-to-watch
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

struct TrendingGridView: View {
    let results: [TMDBSearchResult]
    let isLoading: Bool
    let isOnWatchlist: (TMDBSearchResult) -> Bool
    let onSelect: (TMDBSearchResult) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else if !results.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trending This Week")
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(results) { result in
                            PosterCard(result: result, isOnWatchlist: isOnWatchlist(result))
                                .onTapGesture { onSelect(result) }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
    }
}

struct PosterCard: View {
    let result: TMDBSearchResult
    let isOnWatchlist: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedAsyncImage(url: result.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                if isOnWatchlist {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .background(Circle().fill(.green))
                        .padding(4)
                }
            }

            Text(result.displayTitle)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }
}

struct SearchResultRow: View {
    let result: TMDBSearchResult
    let isOnWatchlist: Bool

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: result.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 48, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Text(result.displayTitle)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if let type = result.resolvedMediaType {
                        Image(systemName: type.systemImage)
                            .font(.caption2)
                        Text(type.displayName)
                            .font(.caption)
                    }
                    if !result.releaseYear.isEmpty {
                        Text("· \(result.releaseYear)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isOnWatchlist {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
