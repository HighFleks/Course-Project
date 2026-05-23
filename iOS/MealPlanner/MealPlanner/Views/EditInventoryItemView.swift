import Foundation
import SwiftUI
import Combine

struct EditInventoryItemView: View {
    @ObservedObject var viewModel: InventoryViewModel
    var item: InventoryItem
    @State private var quantityString = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("\(item.ingredient.name)") {
                    TextField("Количество", text: $quantityString)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Изменить количество")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if let qty = Double(quantityString.replacingOccurrences(of: ",", with: ".")) {
                            viewModel.updateItem(ingredientID: item.ingredient_id, newQuantity: qty)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear { quantityString = String(format: "%.1f", item.quantity) }
        }
    }
}
