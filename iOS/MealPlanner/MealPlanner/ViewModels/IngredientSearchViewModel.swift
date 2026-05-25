import Foundation
import SwiftUI
import Combine

@MainActor
class IngredientSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Ingredient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = APIService.shared
    private var searchTask: Task<Void, Never>?

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            results = []
            errorMessage = nil
            isLoading = false
            return
        }
        // Отменяем предыдущую задачу
        searchTask?.cancel()
        searchTask = Task { [trimmed] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let data = try await service.get(
                    path: "/api/ingredients/search",
                    queryItems: [URLQueryItem(name: "q", value: trimmed)]
                )
                if Task.isCancelled { return }
                results = try JSONDecoder().decode([Ingredient].self, from: data)
            } catch {
                if Task.isCancelled { return }
                errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                results = []
            }
        }
    }
}
