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

// Вспомогательный экран добавления продукта (упрощённо)
struct AddInventoryItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
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
