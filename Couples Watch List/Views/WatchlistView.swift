import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.addedAt, order: .reverse) private var items: [WatchlistItem]

    @State private var statusFilter: WatchStatus?

    private var filtered: [WatchlistItem] {
        items.filter { item in
            item.mediaType == .tv &&
            (statusFilter == nil || item.derivedStatus == statusFilter)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "Your watchlist is empty",
                        systemImage: "popcorn",
                        description: Text("Tap Search to find TV shows to add.")
                    )
                } else {
                    List {
                        ForEach(filtered) { item in
                            if !item.seasonProgresses.isEmpty {
                                NavigationLink(destination: TVShowProgressView(item: item)) {
                                    WatchlistRowView(item: item)
                                }
                            } else {
                                WatchlistRowView(item: item)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button { statusFilter = nil } label: {
                Label("All", systemImage: statusFilter == nil ? "checkmark" : "")
            }
            ForEach(WatchStatus.allCases, id: \.self) { s in
                Button { statusFilter = s } label: {
                    Label(s.rawValue, systemImage: statusFilter == s ? "checkmark" : "")
                }
            }
        } label: {
            Label("Filter", systemImage: statusFilter != nil
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filtered[index])
        }
    }
}
