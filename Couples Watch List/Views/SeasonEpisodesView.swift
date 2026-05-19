import SwiftUI

struct SeasonEpisodesView: View {
    @Bindable var season: SeasonProgress
    let item: WatchlistItem

    var body: some View {
        List {
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
                        let isWatched = season.status == .watched || season.watchedEpisodes.contains(ep)
                        HStack {
                            Text("Episode \(ep)")
                            Spacer()
                            Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isWatched ? .green : .secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggleEpisode(ep) }
                    }
                }
            }
        }
        .navigationTitle(season.name)
        .navigationBarTitleDisplayMode(.inline)
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
