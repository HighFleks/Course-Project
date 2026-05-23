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
            results = []
            return
        }
        // Отменяем предыдущую задачу
        searchTask?.cancel()
        searchTask = Task {
            // Задержка 0.3 сек, чтобы не спамить сервер
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                defer { isLoading = false }
                Task {
                    do {
                        let data = try await service.get(path: "/api/ingredients/search",
                                                         queryItems: [URLQueryItem(name: "q", value: trimmed)])
                        let decoder = JSONDecoder()
                        results = try decoder.decode([Ingredient].self, from: data)
                    } catch {
                        errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                        results = []
                    }
                }
            }
        }
    }
}
