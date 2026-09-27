import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    let onBarcodeDetected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var torchOn = false
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var showManualEntry = false
    @State private var manualCode = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraStatus == .authorized {
                BarcodeCameraPreview(onBarcodeDetected: onBarcodeDetected)
                    .ignoresSafeArea()
                scanOverlay
            } else if cameraStatus == .notDetermined {
                ProgressView().tint(.white)
            } else {
                cameraUnavailable
            }

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
                    .accessibilityLabel("Close scanner")
                    Spacer()
                    if cameraStatus == .authorized {
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
                        .accessibilityLabel(torchOn ? "Turn flashlight off" : "Turn flashlight on")
                    }
                }
                .padding(FDSpacing.lg)

                Spacer()

                VStack(spacing: FDSpacing.sm) {
                    if cameraStatus == .authorized {
                        Text("Align barcode in frame")
                            .font(.fdHeadline)
                            .foregroundColor(.white)
                        Text("It's detected automatically")
                            .font(.fdSubheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Button {
                        showManualEntry = true
                    } label: {
                        Label("Type barcode number", systemImage: "keyboard")
                            .font(.fdSubheadline)
                            .foregroundColor(.fdGreen)
                    }
                    .padding(.top, 4)
                }
                .padding(FDSpacing.lg)
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
                .padding(.bottom, FDSpacing.xxl)
            }
        }
        .task {
            if cameraStatus == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
        .alert("Enter Barcode", isPresented: $showManualEntry) {
            TextField("e.g. 3017620422003", text: $manualCode)
                .keyboardType(.numberPad)
            Button("Look Up") {
                let code = manualCode.filter(\.isNumber)
                if !code.isEmpty { onBarcodeDetected(code) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The number printed under the barcode.")
        }
        .onDisappear { if torchOn { toggleTorch(false) } }
    }

    private var scanOverlay: some View {
        GeometryReader { geo in
            let scanWidth: CGFloat = min(geo.size.width * 0.8, 320)
            let scanHeight: CGFloat = scanWidth * 0.55

            ZStack {
                Color.black.opacity(0.55)
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: scanWidth, height: scanHeight)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            ScanFrame(width: scanWidth, height: scanHeight)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var cameraUnavailable: some View {
        VStack(spacing: FDSpacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.6))
            Text("Camera Access Needed")
                .font(.fdTitle3)
                .foregroundColor(.white)
            Text("Allow camera access in Settings to scan barcodes, or type the number instead.")
                .font(.fdSubheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.fdGreen)
        }
        .padding(FDSpacing.xl)
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
    let width: CGFloat
    let height: CGFloat
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
        .frame(width: width + lineWidth, height: height + lineWidth)
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

    /// Keeps the camera preview layer sized to the view on every layout pass.
    final class PreviewContainerView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }
    }

    func makeUIView(context: Context) -> UIView {
        let view = PreviewContainerView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        guard session.canAddInput(input) else { return view }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        // Food packaging uses EAN/UPC codes
        output.metadataObjectTypes = [.ean8, .ean13, .upce]

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

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        let session = coordinator.session
        DispatchQueue.global(qos: .userInitiated).async {
            session?.stopRunning()
        }
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
