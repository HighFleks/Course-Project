import Foundation
import SwiftUI
import Combine

struct AddShoppingItemView: View {
    @ObservedObject var viewModel: ShoppingListViewModel
    @State private var selectedIngredient: Ingredient?
    @State private var quantityString = ""
    @State private var showSearch = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Продукт") {
                    Button(action: { showSearch = true }) {
                        HStack {
                            Text(selectedIngredient?.name ?? "Выберите продукт")
                                .foregroundColor(selectedIngredient == nil ? .blue : .primary)
                            Spacer()
                            if selectedIngredient != nil { Image(systemName: "checkmark") }
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
                    Button("Добавить") {
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
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            .sheet(isPresented: $showSearch) {
                SelectIngredientView(selectedIngredient: $selectedIngredient)
            }
        }
    }
}
