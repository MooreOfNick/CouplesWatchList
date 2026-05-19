import SwiftUI
import SwiftData

fileprivate struct UpNextEntry: Identifiable {
    let item: WatchlistItem
    let season: SeasonProgress
    let episodeNumber: Int
    var id: PersistentIdentifier { item.id }
}

struct HomeView: View {
    @Query(sort: \WatchlistItem.addedAt, order: .reverse) private var items: [WatchlistItem]

    private var currentlyWatching: [WatchlistItem] {
        items.filter { $0.derivedStatus == .watching }
    }

    private var wantToWatch: [WatchlistItem] {
        items.filter { $0.derivedStatus == .wantToWatch }
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

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "popcorn",
                        description: Text("Search for movies and TV shows to get started.")
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
                                    if item.mediaType == .tv && !item.seasonProgresses.isEmpty {
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
                                    if item.mediaType == .tv && !item.seasonProgresses.isEmpty {
                                        NavigationLink(destination: TVShowProgressView(item: item)) {
                                            HomeItemRow(item: item)
                                        }
                                    } else {
                                        HomeItemRow(item: item)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Home")
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
                        Image(systemName: item.mediaType.systemImage)
                            .font(.caption2)
                        Text(item.mediaType.displayName)
                            .font(.caption)
                        if !item.releaseYear.isEmpty {
                            Text("· \(item.releaseYear)")
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
