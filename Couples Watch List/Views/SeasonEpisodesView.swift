import SwiftUI

struct SeasonEpisodesView: View {
    @Bindable var season: SeasonProgress
    let item: WatchlistItem

    @State private var seasonDetails: TMDBSeasonDetails?

    private var watchedSet: Set<Int> { Set(season.watchedEpisodes) }

    private func episodeDetail(for number: Int) -> TMDBEpisodeDetail? {
        seasonDetails?.episodes.first { $0.episodeNumber == number }
    }

    var body: some View {
        List {
            if let details = seasonDetails {
                SeasonPosterHeader(details: details)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
            }

            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Menu(season.status.rawValue) {
                        ForEach(WatchStatus.allCases, id: \.self) { s in
                            Button(s.rawValue) { setSeasonStatus(s) }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            if season.episodeCount > 0 {
                Section("Episodes") {
                    ForEach(1...season.episodeCount, id: \.self) { ep in
                        let isWatched = season.status == .watched || watchedSet.contains(ep)
                        EpisodeRow(
                            number: ep,
                            detail: episodeDetail(for: ep),
                            isWatched: isWatched
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { toggleEpisode(ep) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if isWatched {
                                Button {
                                    toggleEpisode(ep)
                                } label: {
                                    Label("Unwatch", systemImage: "arrow.uturn.backward.circle.fill")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    toggleEpisode(ep)
                                } label: {
                                    Label("Watched", systemImage: "checkmark.circle.fill")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(season.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            seasonDetails = try? await TMDBService.shared.fetchSeasonDetails(
                showID: item.tmdbID,
                seasonNumber: season.seasonNumber
            )
        }
    }

    private func toggleEpisode(_ ep: Int) {
        if season.watchedEpisodes.contains(ep) {
            season.watchedEpisodes.removeAll { $0 == ep }
            if season.status == .watched {
                season.status = .watching
            }
        } else {
            season.watchedEpisodes.append(ep)
            if season.status == .wantToWatch {
                season.status = .watching
            }
            if season.watchedEpisodes.count == season.episodeCount {
                season.status = .watched
                advanceToNextSeason()
            }
        }
    }

    private func setSeasonStatus(_ newStatus: WatchStatus) {
        guard newStatus != season.status else { return }
        season.status = newStatus
        switch newStatus {
        case .watched:
            season.watchedEpisodes = Array(1...season.episodeCount)
            advanceToNextSeason()
        case .wantToWatch:
            season.watchedEpisodes = []
        case .watching:
            break
        }
    }

    private func advanceToNextSeason() {
        let sorted = item.seasonProgresses.sorted { $0.seasonNumber < $1.seasonNumber }
        guard let idx = sorted.firstIndex(where: { $0.id == season.id }),
              idx + 1 < sorted.count else { return }
        let next = sorted[idx + 1]
        guard next.status == .wantToWatch else { return }
        next.status = .watching
    }
}

private struct SeasonPosterHeader: View {
    let details: TMDBSeasonDetails

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if let url = details.posterURL {
                CachedAsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.2))
                }
                .frame(width: 90, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            }

            if let overview = details.overview, !overview.isEmpty {
                Text(overview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(7)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct EpisodeRow: View {
    let number: Int
    let detail: TMDBEpisodeDetail?
    let isWatched: Bool

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: detail?.stillURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(number)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(detail?.name ?? "Episode \(number)")
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isWatched ? .green : .secondary)
                .font(.title3)
        }
        .padding(.vertical, 4)
    }
}
