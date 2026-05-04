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

    @Published var quantity = 1.0

    private let service = APIService.shared
    var captureSession: AVCaptureSession?

    override init() {
        super.init()
        // Камера будет настроена после получения разрешения
    }

    // MARK: - Запрос разрешения и настройка камеры
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
            errorMessage = "Доступ к камере запрещён. Разрешите его в Настройках."
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

    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else { return }

        if barcode == scannedBarcode { return }
        scannedBarcode = barcode
        fetchProductInfo(barcode: barcode)
    }

    // MARK: - Запрос к серверу
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
            } catch {
                self.errorMessage = "Продукт не найден. Попробуйте снова."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.scannedBarcode = nil
                    self.productName = nil
                    self.ingredientId = nil
                }
            }
        }
    }

    // MARK: - Добавление в инвентарь
    func addToInventory() {
        guard let id = ingredientId else { return }
        Task {
            do {
                let body = InventoryItemRequest(ingredient_id: id, quantity: quantity)
                _ = try await service.request(method: "POST", path: "/api/inventory/", body: body)
                reset()
            } catch {
                errorMessage = "Не удалось добавить в инвентарь"
            }
        }
    }

    func reset() {
        scannedBarcode = nil
        productName = nil
        ingredientId = nil
        errorMessage = nil
        quantity = 1.0
    }
}
