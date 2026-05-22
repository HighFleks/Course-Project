import SwiftUI

struct HomeView: View {
    @State private var isShowingRecipeForm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Рецепты") {
                    NavigationLink(destination: RecipesListView()) { Label("📖 Все рецепты", systemImage: "book") }
                    NavigationLink(destination: FavoritesView()) { Label("⭐️ Избранное", systemImage: "star") }
                    Button(action: { isShowingRecipeForm = true }) { Label("📝 Создать рецепт", systemImage: "plus.circle") }
                    NavigationLink(destination: RandomRecipeView()) { Label("🎲 Что приготовить?", systemImage: "dice") }
                }

                Section("Мои продукты") {
                    NavigationLink(destination: InventoryView()) { Label("🧺 Инвентарь", systemImage: "basket") }
                    NavigationLink(destination: ShoppingListView()) { Label("🛒 Список покупок", systemImage: "cart") }
                }

                Section("Инструменты") {
                    NavigationLink(destination: BarcodeScannerView()) { Label("📸 Сканер штрих-кодов", systemImage: "barcode.viewfinder") }
                }
            }
            .navigationTitle("Meal Planner")
            .sheet(isPresented: $isShowingRecipeForm) {
                RecipeFormView()
            }
        }
    }
}
