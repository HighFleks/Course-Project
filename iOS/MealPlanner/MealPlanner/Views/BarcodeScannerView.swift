import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @StateObject private var viewModel = BarcodeScannerViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.captureSession)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button("Закрыть") { dismiss() }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
                Spacer()

                if viewModel.isLoading {
                    ProgressView("Ищем продукт...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                } else if viewModel.showConfirmation {
                    VStack(spacing: 12) {
                        if viewModel.isManualEntry {
                            VStack(spacing: 4) {
                                Text("Продукт не найден")
                                    .font(.headline)
                                Text("Введите данные вручную")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Найден продукт:")
                                .font(.headline)
                        }

                        TextField("Название продукта", text: $viewModel.confirmedProductName)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.sentences)
                            .onChange(of: viewModel.confirmedProductName) { newValue in
                                viewModel.onProductNameChanged(newValue)
                            }

                        // Подсказки из базы
                        if !viewModel.searchResults.isEmpty {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 4) {
                                    ForEach(viewModel.searchResults) { ingredient in
                                        Button {
                                            viewModel.selectIngredient(ingredient)
                                        } label: {
                                            HStack {
                                                Text(ingredient.name)
                                                Spacer()
                                                if let unit = ingredient.unit {
                                                    Text(unit).foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }

                        HStack {
                            Text("Кол-во:")
                            TextField("Количество", value: $viewModel.quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            if viewModel.isManualEntry && viewModel.ingredientId == nil {
                                Picker("", selection: $viewModel.confirmedUnit) {
                                    ForEach(["шт", "г", "мл"], id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 140)
                            } else {
                                Text(viewModel.confirmedUnit)
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        HStack(spacing: 16) {
                            Button("Подтвердить") {
                                Task { await viewModel.confirmAdd() }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Отмена") {
                                viewModel.reset()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding()
                } else if let productName = viewModel.productName, productName.hasPrefix("Добавлено:") {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text(productName)
                            .font(.title2)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(.red.opacity(0.8))
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear { viewModel.requestPermissionAndSetup() }
        .onDisappear { viewModel.stopScanning() }
    }
}

// UIViewRepresentable для отображения камеры в SwiftUI
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        guard let session = session else { return view }
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let session = session else { return }
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            previewLayer.session = session
        } else {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = uiView.bounds
            uiView.layer.addSublayer(previewLayer)
        }
    }
}
