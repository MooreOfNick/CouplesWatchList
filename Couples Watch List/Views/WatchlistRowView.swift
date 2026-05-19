import SwiftUI

struct WatchlistRowView: View {
    @Bindable var item: WatchlistItem

    private var hasSeasonTracking: Bool {
        item.mediaType == .tv && !item.seasonProgresses.isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterURL) { image in
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

                HStack(spacing: 4) {
                    Image(systemName: item.mediaType.systemImage)
                        .font(.caption2)
                    Text(item.mediaType.displayName)
                        .font(.caption)
                    if !item.releaseYear.isEmpty {
                        Text("· \(item.releaseYear)")
                            .font(.caption)
                    }
                    if item.mediaType == .tv, let seasons = item.numberOfSeasons {
                        Text("· \(seasons) season\(seasons == 1 ? "" : "s")")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)

                if hasSeasonTracking {
                    Text(item.derivedStatus.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Status", selection: $item.status) {
                        ForEach(WatchStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                    .padding(.leading, -8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
