import SwiftUI
import PhotosUI
import SwiftData

/// Photo or description in, recognized foods with editable portions out.
struct AIFoodScanView: View {
    @ObservedObject var vm: FoodViewModel
    var startWithCamera: Bool = false
    let onLogged: (Int) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var note = ""
    @State private var showCamera = false
    @State private var isAnalyzing = false
    @State private var estimate: AIFoodEstimate? = nil
    @State private var included: Set<UUID> = []
    @State private var errorMessage: String? = nil
    @State private var isConfigured = AIFoodAnalyzer.isConfigured
    @State private var didAutoOpenCamera = false

    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private var canAnalyze: Bool { image != nil || note.trimmingCharacters(in: .whitespaces).count >= 3 }

    var body: some View {
        NavigationStack {
            Group {
                if !isConfigured {
                    AIKeySetupView { isConfigured = true }
                } else if let estimate {
                    results(estimate)
                } else {
                    input
                }
            }
            .navigationTitle("AI Food Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if estimate != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Retake") {
                            estimate = nil
                            image = nil
                        }
                    }
                }
            }
            .keyboardDoneButton()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $image).ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                    image = picked
                }
            }
        }
        .onAppear {
            if startWithCamera && cameraAvailable && isConfigured && !didAutoOpenCamera {
                didAutoOpenCamera = true
                showCamera = true
            }
        }
    }

    // MARK: - Input

    private var input: some View {
        ScrollView {
            VStack(spacing: FDSpacing.lg) {
                photoArea

                HStack(spacing: FDSpacing.sm) {
                    if cameraAvailable {
                        QuickActionButton(icon: "camera.fill", title: "Take Photo") { showCamera = true }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3)
                            Text("Choose Photo")
                                .font(.fdCaption)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundColor(.fdGreen)
                        .background(Color.fdGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
                    }
                }

                VStack(alignment: .leading, spacing: FDSpacing.sm) {
                    Text(image == nil ? "Or describe what you ate" : "Anything to add? (optional)")
                        .font(.fdSubheadline)
                        .foregroundColor(.fdSecondaryLabel)
                    TextField("e.g. 10 ćevapa u lepinji s lukom", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(FDSpacing.sm + 2)
                        .background(Color.fdCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.fdSubheadline)
                        .foregroundColor(.fdOrange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                FDPrimaryButton(isAnalyzing ? "Analyzing your meal…" : "Estimate Calories", icon: "sparkles", isLoading: isAnalyzing) {
                    analyze()
                }
                .disabled(!canAnalyze || isAnalyzing)
                .opacity(canAnalyze ? 1 : 0.5)

                Text("Your photo and description are sent to Anthropic's Claude to estimate nutrition. Estimates can be off by 20% or more, so check portions before logging.")
                    .font(.fdCaption)
                    .foregroundColor(.fdTertiaryLabel)
                    .multilineTextAlignment(.center)
            }
            .padding(FDSpacing.md)
        }
        .background(Color.fdGroupedBackground)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var photoArea: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 240)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
                .overlay(alignment: .topTrailing) {
                    Button {
                        self.image = nil
                        photoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .padding(FDSpacing.sm)
                    }
                    .accessibilityLabel("Remove photo")
                }
        } else {
            VStack(spacing: FDSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.fdPrimary)
                Text("Snap your plate")
                    .font(.fdTitle3)
                Text("Works for home cooking and local dishes without barcodes.")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.fdCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
        }
    }

    private func analyze() {
        errorMessage = nil
        isAnalyzing = true
        let photo = image
        let text = note
        Task {
            do {
                let result = try await AIFoodAnalyzer().analyze(image: photo, description: text)
                estimate = result
                included = Set(result.items.map(\.id))
                Haptics.success()
            } catch let error as AIFoodError {
                errorMessage = error.localizedDescription
                if error == .invalidAPIKey || error == .missingAPIKey { isConfigured = false }
                Haptics.warning()
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    // MARK: - Results

    private func results(_ estimate: AIFoodEstimate) -> some View {
        let chosen = estimate.items.filter { included.contains($0.id) }
        return List {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(estimate.mealDescription)
                            .font(.fdHeadline)
                        if !estimate.notes.isEmpty {
                            Text(estimate.notes)
                                .font(.fdCaption)
                                .foregroundColor(.fdSecondaryLabel)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Int(chosen.reduce(0) { $0 + $1.calories }))")
                            .font(.fdTitle2)
                            .monospacedDigit()
                        Text("kcal")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
            }

            Section {
                ForEach(estimate.items) { item in
                    AIFoodItemRow(
                        item: item,
                        isIncluded: included.contains(item.id),
                        onToggle: {
                            if included.contains(item.id) { included.remove(item.id) } else { included.insert(item.id) }
                            Haptics.selection()
                        },
                        onGramsChange: { grams in updateGrams(of: item.id, to: grams) }
                    )
                }
            } header: {
                Text("Tap the amount to adjust it")
            }

            Section {
                Picker("Meal", selection: $vm.selectedMealType) {
                    ForEach(MealType.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
                Button {
                    let logged = vm.logAIItems(chosen, mealType: vm.selectedMealType, modelContext: modelContext)
                    onLogged(logged.count)
                    dismiss()
                } label: {
                    Text(chosen.count == 1 ? "Log 1 Item" : "Log \(chosen.count) Items")
                        .font(.fdHeadline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(chosen.isEmpty)
                .listRowBackground(chosen.isEmpty ? Color.fdGreen.opacity(0.4) : Color.fdGreen)
                .foregroundColor(.white)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func updateGrams(of id: UUID, to grams: Double) {
        guard var current = estimate, let index = current.items.firstIndex(where: { $0.id == id }) else { return }
        current.items[index] = current.items[index].scaled(toGrams: grams)
        estimate = current
    }
}

struct AIFoodItemRow: View {
    let item: AIFoodItem
    let isIncluded: Bool
    let onToggle: () -> Void
    let onGramsChange: (Double) -> Void
    @State private var grams: Double? = nil

    var confidenceColor: Color {
        switch item.confidence {
        case "high": return .fdGreen
        case "medium": return .fdOrange
        default: return .fdRed
        }
    }

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            Button(action: onToggle) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isIncluded ? .fdGreen : .fdTertiaryLabel)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isIncluded ? "Included" : "Not included")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.fdSubheadline.weight(.semibold))
                        .foregroundColor(isIncluded ? .fdLabel : .fdTertiaryLabel)
                    FDBadge(text: item.confidence, color: confidenceColor)
                }
                Text("P \(Int(item.proteinG)) · C \(Int(item.carbsG)) · F \(Int(item.fatG))")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    TextField("g", value: $grams, format: .number.precision(.fractionLength(0)))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .onSubmit(commit)
                    Text("g").foregroundColor(.fdSecondaryLabel)
                }
                .font(.fdSubheadline)
                Text("\(Int(item.calories)) kcal")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                    .monospacedDigit()
            }
        }
        .onAppear { grams = item.estimatedGrams.rounded() }
        .onChange(of: grams) { commit() }
    }

    private func commit() {
        if let grams, grams > 0, abs(grams - item.estimatedGrams) >= 1 {
            onGramsChange(grams)
        }
    }
}

/// Explains why a key is needed and stores it in the Keychain.
struct AIKeySetupView: View {
    let onSaved: () -> Void
    @State private var key = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: FDSpacing.sm) {
                    Label("Recognize food from a photo", systemImage: "sparkles")
                        .font(.fdHeadline)
                    Text("FitDrop uses Anthropic's Claude to identify dishes, including local food without barcodes, and estimate calories and macros. It needs your own Claude API key. A photo typically costs a few cents.")
                        .font(.fdSubheadline)
                        .foregroundColor(.fdSecondaryLabel)
                }
                .padding(.vertical, 4)
            }
            Section {
                SecureField("sk-ant-…", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save Key") {
                    KeychainStore.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: AIFoodAnalyzer.apiKeyKeychainKey)
                    Haptics.success()
                    onSaved()
                }
                .disabled(!key.trimmingCharacters(in: .whitespaces).hasPrefix("sk-ant-"))
            } header: {
                Text("Claude API key")
            } footer: {
                Text("Create a key at console.anthropic.com under API Keys. It's stored only in this iPhone's Keychain and sent only to Anthropic.")
            }
            Section {
                Button {
                    if let url = URL(string: "https://console.anthropic.com/settings/keys") { openURL(url) }
                } label: {
                    Label("Get an API Key", systemImage: "arrow.up.right.square")
                }
            }
        }
    }
}

/// Wraps the system camera, since SwiftUI has no native camera picker.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
