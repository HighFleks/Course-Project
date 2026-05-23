import SwiftUI

struct HomeView: View {
    @State private var isShowingRecipeForm = false
    @ObservedObject private var plannedVM = PlannedRecipesViewModel.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Рецепты") {
                    NavigationLink(destination: RecipesListView()) { Label("📖 Все рецепты", systemImage: "book") }
                    NavigationLink(destination: FavoritesView()) { Label("⭐️ Избранное", systemImage: "star") }
                    Button(action: { isShowingRecipeForm = true }) { Label("📝 Создать рецепт", systemImage: "plus.circle") }
                    NavigationLink(destination: RandomRecipeView()) { Label("🎲 Что приготовить?", systemImage: "dice") }

                    // Новая строка с бейджиком
                    NavigationLink(destination: PlannedRecipesView()) {
                        HStack {
                            Label("📅 План приготовления", systemImage: "calendar")
                            Spacer()
                            if plannedVM.plannedRecipes.count > 0 {
                                Text("\(plannedVM.plannedRecipes.count)")
                                    .font(.caption2).bold()
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.orange))
                            }
                        }
                    }
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
