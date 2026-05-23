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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.editingItem = item   // сохраняем выбранный элемент
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
            .sheet(item: $viewModel.editingItem) { item in
                EditInventoryItemView(viewModel: viewModel, item: item)
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
