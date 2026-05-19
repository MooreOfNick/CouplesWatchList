import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.addedAt, order: .reverse) private var items: [WatchlistItem]

    @State private var statusFilter: WatchStatus?
    @State private var typeFilter: MediaType?

    private var filtered: [WatchlistItem] {
        items.filter { item in
            (statusFilter == nil || item.derivedStatus == statusFilter) &&
            (typeFilter == nil || item.mediaType == typeFilter)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        "Your watchlist is empty",
                        systemImage: "popcorn",
                        description: Text("Tap Search to find movies and TV shows to add.")
                    )
                } else {
                    List {
                        ForEach(filtered) { item in
                            if item.mediaType == .tv && !item.seasonProgresses.isEmpty {
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
            Section("Status") {
                Button { statusFilter = nil } label: {
                    Label("All", systemImage: statusFilter == nil ? "checkmark" : "")
                }
                ForEach(WatchStatus.allCases, id: \.self) { s in
                    Button { statusFilter = s } label: {
                        Label(s.rawValue, systemImage: statusFilter == s ? "checkmark" : "")
                    }
                }
            }
            Section("Type") {
                Button { typeFilter = nil } label: {
                    Label("All", systemImage: typeFilter == nil ? "checkmark" : "")
                }
                ForEach(MediaType.allCases, id: \.self) { t in
                    Button { typeFilter = t } label: {
                        Label(t.displayName, systemImage: typeFilter == t ? "checkmark" : "")
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: (statusFilter != nil || typeFilter != nil)
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
