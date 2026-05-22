import SwiftUI

struct SelectIngredientView: View {
    @StateObject private var searchVM = IngredientSearchViewModel()
    @Binding var selectedIngredient: Ingredient?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Название продукта", text: $searchVM.query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onSubmit { searchVM.search() }

                if searchVM.isLoading {
                    ProgressView()
                } else if let error = searchVM.errorMessage {
                    Text(error).foregroundColor(.red)
                } else {
                    List(searchVM.results) { ingredient in
                        Button {
                            selectedIngredient = ingredient
                            dismiss()
                        } label: {
                            HStack {
                                Text(ingredient.name)
                                Spacer()
                                if let unit = ingredient.unit {
                                    Text(unit).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Поиск продукта")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onChange(of: searchVM.query) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    searchVM.search()
                }
            }
        }
    }
}
