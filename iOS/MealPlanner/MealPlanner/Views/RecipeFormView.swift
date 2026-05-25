import SwiftUI

struct RecipeFormView: View {
    @StateObject private var viewModel = RecipeFormViewModel()
    @Environment(\.dismiss) private var dismiss
    var recipeToEdit: Recipe?

    @State private var showAddIngredient = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например, Омлет с помидорами", text: $viewModel.name)
                }
                Section("Описание") {
                    TextField("Краткое описание блюда", text: $viewModel.description, axis: .vertical)
                }
                Section("Инструкция") {
                    TextField("1. Разбить яйца в миску\n2. Добавить молоко\n3. Жарить на сковороде", text: $viewModel.instructions, axis: .vertical)
                }
                Section("Категория") {
                    Picker("Категория", selection: $viewModel.category) {
                        ForEach(viewModel.categories, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section("Публичный") {
                    Toggle("Доступен всем", isOn: $viewModel.isPublic)
                }
                Section("Ингредиенты") {
                    ForEach(viewModel.ingredients) { draft in
                        HStack {
                            Text(draft.ingredient.name)
                            Spacer()
                            Text("\(draft.quantity, specifier: "%.1f") \(draft.ingredient.unit ?? "")")
                                .foregroundColor(.secondary)
                        }
                    }.onDelete { indexSet in
                        for i in indexSet { viewModel.removeIngredient(viewModel.ingredients[i]) }
                    }
                    Button("Добавить ингредиент") { showAddIngredient = true }
                }
                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red)
                }
                if let success = viewModel.successMessage {
                    Text(success).foregroundColor(.green)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                        }
                }
                Section {
                    Button(recipeToEdit == nil ? "Создать рецепт" : "Сохранить изменения") {
                        viewModel.save(existingRecipeId: recipeToEdit?.id)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle(recipeToEdit == nil ? "Новый рецепт" : "Редактирование")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .sheet(isPresented: $showAddIngredient) { AddIngredientToRecipeView(viewModel: viewModel) }
            .onAppear { if let recipe = recipeToEdit { viewModel.loadRecipe(recipe) } }
        }
    }
}

struct AddIngredientToRecipeView: View {
    @ObservedObject var viewModel: RecipeFormViewModel
    @State private var searchQuery = ""
    @State private var quantityString = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Название ингредиента", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: searchQuery) { newValue in
                        viewModel.search(query: newValue)
                    }

                List(viewModel.searchResults) { ingredient in
                    Button {
                        if let qty = Double(quantityString.replacingOccurrences(of: ",", with: ".")), qty > 0 {
                            viewModel.addIngredient(ingredient, quantity: qty)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(ingredient.name)
                            Spacer()
                            if let unit = ingredient.unit { Text(unit).foregroundColor(.secondary) }
                        }
                    }
                }

                if !viewModel.searchResults.isEmpty {
                    HStack {
                        Text("Количество:")
                        TextField("0.0", text: $quantityString)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding()
                }
                Spacer()
            }
            .navigationTitle("Добавить ингредиент")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
        }
    }
}
