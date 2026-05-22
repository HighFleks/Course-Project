import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red)
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            HStack {
                                Text(item.ingredient.name)
                                Spacer()
                                Text("\(item.quantity, specifier: "%.1f") \(item.ingredient.unit ?? "")")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("Мой инвентарь")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddInventoryItemView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.loadInventory()
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

struct AddInventoryItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedIngredient: Ingredient?
    @State private var quantityString = ""
    @State private var showSearch = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Продукт") {
                    Button {
                        showSearch = true
                    } label: {
                        HStack {
                            Text(selectedIngredient?.name ?? "Выберите продукт")
                                .foregroundColor(selectedIngredient == nil ? .blue : .primary)
                            Spacer()
                            if selectedIngredient != nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if let ingredient = selectedIngredient {
                    Section("Количество (\(ingredient.unit ?? "-"))") {
                        TextField("0.0", text: $quantityString)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Добавить в инвентарь") {
                        guard let ing = selectedIngredient,
                              let qty = Double(quantityString.replacingOccurrences(of: ",", with: ".")),
                              qty > 0 else { return }
                        viewModel.addItem(ingredientID: ing.id, quantity: qty)
                        dismiss()
                    }
                    .disabled(selectedIngredient == nil || quantityString.isEmpty)
                }
            }
            .navigationTitle("Добавить продукт")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .sheet(isPresented: $showSearch) {
                SelectIngredientView(selectedIngredient: $selectedIngredient)
            }
        }
    }
}

