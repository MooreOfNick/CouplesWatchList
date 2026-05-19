import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var watchlist: [WatchlistItem]

    @State private var viewModel = SearchViewModel()
    @State private var selectedResult: TMDBSearchResult?

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Movies & TV shows")
            .onChange(of: viewModel.query) { viewModel.search() }
            .sheet(item: $selectedResult) { result in
                MediaDetailView(
                    result: result,
                    isOnWatchlist: isOnWatchlist(result),
                    onAdd: { tvDetails, status in addToWatchlist(result, tvDetails: tvDetails, status: status) }
                )
            }
        }
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
