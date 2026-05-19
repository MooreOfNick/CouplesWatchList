import SwiftUI

struct TVShowProgressView: View {
    @Bindable var item: WatchlistItem

    private var sortedSeasons: [SeasonProgress] {
        item.seasonProgresses.sorted { $0.seasonNumber < $1.seasonNumber }
    }

    var body: some View {
        List(sortedSeasons) { season in
            NavigationLink(destination: SeasonEpisodesView(season: season, item: item)) {
                SeasonRow(season: season)
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SeasonRow: View {
    let season: SeasonProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(season.name)
                .font(.headline)
            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
