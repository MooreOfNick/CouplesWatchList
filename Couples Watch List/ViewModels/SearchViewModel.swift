import Foundation
import Observation

@Observable
final class SearchViewModel {
    var query = ""
    var results: [TMDBSearchResult] = []
    var isLoading = false
    var errorMessage: String?

    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            results = []
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            do {
                let items = try await TMDBService.shared.searchMulti(query: q)
                guard !Task.isCancelled else { return }
                results = items
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func clear() {
        searchTask?.cancel()
        query = ""
        results = []
        errorMessage = nil
        isLoading = false
    }
}
