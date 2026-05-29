import SwiftUI

struct TVShowProgressView: View {
    @Bindable var item: WatchlistItem

    private var sortedSeasons: [SeasonProgress] {
        item.seasonProgresses.sorted { $0.seasonNumber < $1.seasonNumber }
    }

    private func markAsWatched(_ season: SeasonProgress) {
        season.status = .watched
        season.watchedEpisodes = Array(1...season.episodeCount)
        let sorted = sortedSeasons
        guard let idx = sorted.firstIndex(where: { $0.id == season.id }),
              idx + 1 < sorted.count else { return }
        let next = sorted[idx + 1]
        if next.status == .wantToWatch { next.status = .watching }
    }

    private func markAsUnwatched(_ season: SeasonProgress) {
        season.status = .wantToWatch
        season.watchedEpisodes = []
    }

    var body: some View {
        List {
            ShowPosterHeader(item: item, seasons: sortedSeasons)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))

            ForEach(sortedSeasons) { season in
                NavigationLink(destination: SeasonEpisodesView(season: season, item: item)) {
                    SeasonRow(season: season)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if season.status == .watched {
                        Button {
                            markAsUnwatched(season)
                        } label: {
                            Label("Unwatch", systemImage: "arrow.uturn.backward.circle.fill")
                        }
                        .tint(.orange)
                    } else {
                        Button {
                            markAsWatched(season)
                        } label: {
                            Label("Watched", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct ShowPosterHeader: View {
    let item: WatchlistItem
    let seasons: [SeasonProgress]

    @State private var watchProviders: [TMDBWatchProvider] = []

    private var watchedCount: Int { seasons.filter { $0.status == .watched }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: item.posterURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(width: 90, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 8) {
                    if let n = item.numberOfSeasons {
                        Text("\(n) Season\(n == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                    }

                    if !seasons.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(watchedCount) of \(seasons.count) watched")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ProgressView(value: Double(watchedCount), total: Double(seasons.count))
                                .tint(.green)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            if !item.overview.isEmpty {
                Text(item.overview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !watchProviders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available on")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(watchProviders.prefix(6)) { provider in
                            VStack(spacing: 4) {
                                CachedAsyncImage(url: provider.logoURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.2))
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text(provider.providerName)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 44)
                            }
                        }
                    }
                }
            }
        }
        .task {
            watchProviders = (try? await TMDBService.shared.fetchWatchProviders(showID: item.tmdbID)) ?? []
        }
    }
}

struct SeasonRow: View {
    let season: SeasonProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(season.name)
                .font(.headline)
            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: episodeProgress)
                .tint(season.status == .watched ? .green : .blue)
        }
        .padding(.vertical, 4)
    }

    private var episodeProgress: Double {
        guard season.episodeCount > 0 else { return 0 }
        if season.status == .watched { return 1.0 }
        return Double(season.watchedEpisodes.count) / Double(season.episodeCount)
    }

    private var subtitleText: String {
        let watched = season.watchedEpisodes.count
        let total = season.episodeCount
        switch season.status {
        case .watched:
            return "Watched · \(total)/\(total) episodes"
        case .watching:
            return "Watching · \(watched)/\(total) episodes"
        case .wantToWatch:
            return "Want to Watch · \(total) episodes"
        }
    }
}
