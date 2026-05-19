import SwiftUI

struct MediaDetailView: View {
    let result: TMDBSearchResult
    let isOnWatchlist: Bool
    let onAdd: (TMDBTVDetails?, WatchStatus) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tvDetails: TMDBTVDetails?
    @State private var isLoadingDetails = false
    @State private var showingStatusDialog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AsyncImage(url: result.posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.secondary.opacity(0.15)
                            .aspectRatio(2 / 3, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        if let type = result.resolvedMediaType {
                            HStack(spacing: 6) {
                                Image(systemName: type.systemImage)
                                Text(type.displayName)
                                if !result.releaseYear.isEmpty {
                                    Text("· \(result.releaseYear)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        if result.resolvedMediaType == .tv {
                            if isLoadingDetails {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let details = tvDetails {
                                HStack(spacing: 4) {
                                    Text("\(details.numberOfSeasons) season\(details.numberOfSeasons == 1 ? "" : "s")")
                                    Text("·")
                                    Text("\(details.numberOfEpisodes) episodes")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }

                        if let overview = result.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.body)
                        } else {
                            Text("No description available.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            showingStatusDialog = true
                        } label: {
                            Label(
                                isOnWatchlist ? "Already on Watchlist" : "Add to Watchlist",
                                systemImage: isOnWatchlist ? "checkmark.circle.fill" : "plus.circle.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isOnWatchlist)
                        .padding(.top, 4)
                        .confirmationDialog("Add to Watchlist", isPresented: $showingStatusDialog) {
                            ForEach(WatchStatus.allCases, id: \.self) { status in
                                Button(status.rawValue) {
                                    onAdd(tvDetails, status)
                                    dismiss()
                                }
                            }
                        } message: {
                            Text("How would you like to track this?")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(result.displayTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard result.resolvedMediaType == .tv else { return }
                isLoadingDetails = true
                tvDetails = try? await TMDBService.shared.fetchTVDetails(id: result.id)
                isLoadingDetails = false
            }
        }
    }
}
