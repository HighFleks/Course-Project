import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
class BarcodeScannerViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedBarcode: String?
    @Published var productName: String?
    @Published var ingredientId: Int?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var showConfirmation = false
    @Published var quantity: Double = 1.0
    @Published var confirmedProductName: String = ""
    @Published var confirmedUnit: String = ""

    // Для поиска похожих ингредиентов
    @Published var searchResults: [Ingredient] = []
    private var searchTask: Task<Void, Never>?

    private let service = APIService.shared
    var captureSession: AVCaptureSession?

    override init() {
        super.init()
    }

    func requestPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
            startScanning()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                        self?.startScanning()
                    } else {
                        self?.errorMessage = "Доступ к камере запрещён"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Доступ к камере запрещён. Разрешите в Настройках."
        @unknown default:
            break
        }
    }

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            errorMessage = "Камера недоступна"
            return
        }
        captureSession = AVCaptureSession()
        captureSession?.addInput(input)
        let output = AVCaptureMetadataOutput()
        captureSession?.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.ean13, .ean8, .code128, .qr]
    }

    func startScanning() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else { return }
        if barcode == scannedBarcode { return }
        scannedBarcode = barcode
        fetchProductInfo(barcode: barcode)
    }

    private func fetchProductInfo(barcode: String) {
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let body = BarcodeLookupRequest(barcode: barcode)
                let data = try await service.request(method: "POST", path: "/api/barcode/lookup", body: body)
                let decoded = try JSONDecoder().decode(BarcodeLookupResponse.self, from: data)
                self.productName = decoded.product_name
                self.ingredientId = decoded.ingredient_id
                self.confirmedProductName = decoded.product_name
                self.confirmedUnit = decoded.unit ?? "шт"
                self.quantity = extractQuantity(from: decoded.product_name)
                self.showConfirmation = true
                // Сразу выполним поиск для подсказок
                searchIngredients(query: decoded.product_name)
            } catch {
                self.errorMessage = "Продукт не найден"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.scannedBarcode = nil
                    self.productName = nil
                    self.ingredientId = nil
                }
            }
        }
    }

    // Вызывается при изменении текста в поле названия
    func onProductNameChanged(_ newName: String) {
        confirmedProductName = newName
        // Отменяем предыдущую задачу поиска
        searchTask?.cancel()
        searchTask = Task {
            // Задержка 0.3 сек для уменьшения числа запросов
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                searchIngredients(query: newName)
            }
        }
    }

    private func searchIngredients(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        Task {
            do {
                let data = try await service.get(path: "/api/ingredients/search",
                                                 queryItems: [URLQueryItem(name: "q", value: trimmed)])
                let decoder = JSONDecoder()
                self.searchResults = try decoder.decode([Ingredient].self, from: data)
            } catch {
                self.searchResults = []
            }
        }
    }

    // Выбор подсказки
    func selectIngredient(_ ingredient: Ingredient) {
        ingredientId = ingredient.id
        confirmedProductName = ingredient.name
        confirmedUnit = ingredient.unit ?? "шт"
        searchResults = []
    }

    // Подтверждение добавления
    func confirmAdd() async {
        // Если ingredientId отсутствует или название изменилось так, что нет соответствия,
        // попытаемся найти или создать ингредиент с текущим именем
        if ingredientId == nil || confirmedProductName != productName {
            // Ищем точное совпадение
            if let found = try? await findOrCreateIngredient(name: confirmedProductName, unit: confirmedUnit) {
                ingredientId = found.id
                confirmedUnit = found.unit ?? "шт"
            } else {
                errorMessage = "Не удалось сохранить продукт"
                return
            }
        }
        guard let id = ingredientId else { return }
        do {
            let body = InventoryItemRequest(ingredient_id: id, quantity: quantity)
            _ = try await service.request(method: "POST", path: "/api/inventory/", body: body)
            // Успех
            showConfirmation = false
            errorMessage = nil
            productName = "Добавлено: \(confirmedProductName)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.reset()
            }
        } catch {
            errorMessage = "Ошибка добавления"
        }
    }

    private func findOrCreateIngredient(name: String, unit: String) async -> Ingredient? {
        // Сначала поищем точное совпадение
        if let data = try? await service.get(path: "/api/ingredients/search",
                                            queryItems: [URLQueryItem(name: "q", value: name)]),
           let results = try? JSONDecoder().decode([Ingredient].self, from: data),
           let exact = results.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return exact
        }
        // Не нашли — создаём новый
        struct CreateIngredient: Codable { let name: String; let unit: String }
        let body = CreateIngredient(name: name, unit: unit)
        if let data = try? await service.request(method: "POST", path: "/api/ingredients/", body: body),
           let created = try? JSONDecoder().decode(Ingredient.self, from: data) {
            return created
        }
        return nil
    }

    private func extractQuantity(from name: String) -> Double {
            let pattern = "(\\d+[.,]?\\d*)\\s*(г|кг|мл|л|шт|kg|g|l|ml)?"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return 1.0 }
            let nsString = name as NSString
            let results = regex.matches(in: name, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in results {
                if let numberRange = Range(match.range(at: 1), in: name),
                   let unitRange = Range(match.range(at: 2), in: name) {
                    let numberString = String(name[numberRange]).replacingOccurrences(of: ",", with: ".")
                    if let value = Double(numberString) {
                        let unit = String(name[unitRange]).lowercased()
                        switch unit {
                        case "кг", "kg": return value * 1000
                        case "л", "l": return value * 1000
                        default: return value
                        }
                    }
                } else if let numberRange = Range(match.range(at: 1), in: name) {
                    let numberString = String(name[numberRange]).replacingOccurrences(of: ",", with: ".")
                    if let value = Double(numberString) { return value }
                }
            }
            return 1.0
        }

    func reset() {
        scannedBarcode = nil
        productName = nil
        ingredientId = nil
        errorMessage = nil
        quantity = 1.0
        showConfirmation = false
        confirmedProductName = ""
        confirmedUnit = ""
        searchResults = []
    }
}
