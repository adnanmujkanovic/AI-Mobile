import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    let onBarcodeDetected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var torchOn = false

    var body: some View {
        ZStack {
            BarcodeCameraPreview(onBarcodeDetected: onBarcodeDetected)
                .ignoresSafeArea()

            // Overlay
            GeometryReader { geo in
                let scanSize: CGFloat = min(geo.size.width * 0.7, 260)
                let x = (geo.size.width - scanSize) / 2
                let y = (geo.size.height - scanSize) / 2

                // Dark overlay with cutout
                ZStack {
                    Color.black.opacity(0.6)
                    RoundedRectangle(cornerRadius: 16)
                        .frame(width: scanSize, height: scanSize)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

                // Scan frame corners
                ScanFrame(size: scanSize)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .ignoresSafeArea()

            // UI Layer
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button {
                        torchOn.toggle()
                        toggleTorch(torchOn)
                    } label: {
                        Image(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(torchOn ? .fdYellow : .white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(FDSpacing.lg)

                Spacer()

                VStack(spacing: FDSpacing.sm) {
                    Text("Align barcode in frame")
                        .font(.fdHeadline)
                        .foregroundColor(.white)
                    Text("The app will detect it automatically")
                        .font(.fdSubheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(FDSpacing.xl)
                .background(.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
                .padding(.bottom, FDSpacing.xxl)
            }
        }
    }

    private func toggleTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

struct ScanFrame: View {
    let size: CGFloat
    let cornerLength: CGFloat = 28
    let lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            // Top-left
            CornerShape(corner: .topLeft, length: cornerLength, lineWidth: lineWidth)
            // Top-right
            CornerShape(corner: .topRight, length: cornerLength, lineWidth: lineWidth)
            // Bottom-left
            CornerShape(corner: .bottomLeft, length: cornerLength, lineWidth: lineWidth)
            // Bottom-right
            CornerShape(corner: .bottomRight, length: cornerLength, lineWidth: lineWidth)
        }
        .frame(width: size + lineWidth, height: size + lineWidth)
        .foregroundColor(.fdGreen)
    }
}

enum Corner { case topLeft, topRight, bottomLeft, bottomRight }

struct CornerShape: Shape {
    let corner: Corner
    let length: CGFloat
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        case .topRight:
            path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        }
        return path
    }
}

// MARK: - Camera Preview

struct BarcodeCameraPreview: UIViewRepresentable {
    let onBarcodeDetected: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeDetected: onBarcodeDetected)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [
            .ean8, .ean13, .upce, .qr, .code128, .code39, .code93, .dataMatrix
        ]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onBarcodeDetected: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var hasDetected = false

        init(onBarcodeDetected: @escaping (String) -> Void) {
            self.onBarcodeDetected = onBarcodeDetected
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput objects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasDetected,
                  let object = objects.first as? AVMetadataMachineReadableCodeObject,
                  let code = object.stringValue else { return }
            hasDetected = true
            session?.stopRunning()
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            onBarcodeDetected(code)
        }
    }
}

import AudioToolbox
