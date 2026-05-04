import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("Meal Planner")
                    .font(.largeTitle)
                    .bold()

                NavigationLink("📖 Рецепты") {
                    RecipesListView()
                }
                .buttonStyle(.borderedProminent)

                // Позже добавим ссылки на инвентарь и список покупок
                NavigationLink("🧺 Мой инвентарь") {
                    InventoryView()
                }
                .buttonStyle(.borderedProminent)
                
                NavigationLink("🛒 Список покупок") {
                    ShoppingListView()
                }
                .buttonStyle(.borderedProminent)
                
                NavigationLink("📸 Сканер штрихкодов") {
                    BarcodeScannerView()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
        }
    }
}
