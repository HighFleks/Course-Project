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
                    Button("Закрыть") {
                        dismiss()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                Spacer()

                if viewModel.isLoading {
                    ProgressView("Поиск продукта...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                } else if let name = viewModel.productName {
                    VStack(spacing: 12) {
                        Text("Найден продукт:")
                            .font(.headline)
                        Text(name)
                            .font(.title3)

                        HStack {
                            Text("Кол-во:")
                            TextField("Количество", value: $viewModel.quantity, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        HStack(spacing: 16) {
                            Button("Добавить в инвентарь") {
                                viewModel.addToInventory()
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
        .onAppear {
            viewModel.requestPermissionAndSetup()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
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
