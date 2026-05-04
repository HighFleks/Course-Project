import Foundation

// Запрос на сервер
struct BarcodeLookupRequest: Codable {
    let barcode: String
}

// Ответ от сервера (/api/barcode/lookup)
struct BarcodeLookupResponse: Codable {
    let barcode: String
    let product_name: String
    let unit: String?
    let ingredient_id: Int
}
