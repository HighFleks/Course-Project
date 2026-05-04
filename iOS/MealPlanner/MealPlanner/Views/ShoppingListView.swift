import SwiftUI

// MARK: - Основной экран списка покупок
struct ShoppingListView: View {
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showAddSheet = false
    @State private var showGenerateSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error).foregroundColor(.red)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            HStack {
                                Button(action: {
                                    viewModel.updateItem(
                                        ingredientID: item.ingredient_id,
                                        quantity: nil,
                                        isPurchased: !item.is_purchased
                                    )
                                }) {
                                    Image(
                                        systemName: item.is_purchased
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                    .foregroundColor(item.is_purchased ? .green : .gray)
                                }

                                Text(item.ingredient.name)
                                Spacer()
                                Text(
                                    "\(item.quantity, specifier: "%.1f") \(item.ingredient.unit ?? "")"
                                )
                                .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }

                    // Показываем кнопку, только если список НЕ пуст и ВСЕ элементы отмечены
                    if !viewModel.items.isEmpty && viewModel.items.allSatisfy({ $0.is_purchased }) {
                        Button(action: { viewModel.checkout() }) {
                            Text("Завершить покупки")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Список покупок")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showGenerateSheet = true }) {
                        Image(systemName: "wand.and.stars")
                    }
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddShoppingItemView(viewModel: viewModel)   // ✅ теперь эта структура существует
            }
            .sheet(isPresented: $showGenerateSheet) {
                GenerateShoppingListView(viewModel: viewModel)   // ✅ эта тоже
            }
            .onAppear {
                viewModel.loadShoppingList()
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = viewModel.items[index]
            viewModel.deleteItem(ingredientID: item.ingredient_id)
        }
    }
}

// MARK: - Ручное добавление позиции
struct AddShoppingItemView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var ingredientIdString = ""
    @State private var quantityString = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("ID ингредиента", text: $ingredientIdString)
                    .keyboardType(.numberPad)
                TextField("Количество", text: $quantityString)
                    .keyboardType(.decimalPad)
                Button("Добавить") {
                    if let id = Int(ingredientIdString), let qty = Double(quantityString) {
                        viewModel.addItem(ingredientID: id, quantity: qty)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Добавить продукт")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Генерация списка из рецептов
struct GenerateShoppingListView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var recipeIdsText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("ID рецептов через запятую (например 1,2)", text: $recipeIdsText)
                Button("Сгенерировать") {
                    let ids = recipeIdsText
                        .split(separator: ",")
                        .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    viewModel.generateFromRecipes(recipeIDs: ids)
                    dismiss()
                }
            }
            .navigationTitle("Генерация списка")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
