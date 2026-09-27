import SwiftUI
import SwiftData

struct AddFoodView: View {
    @ObservedObject var vm: FoodViewModel
    let savedFoods: [SavedFood]
    let allEntries: [FoodEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tab: ListTab = .recent
    @State private var showScanner = false
    @State private var showQuickAdd = false
    @State private var loggedName: String? = nil
    @FocusState private var searchFocused: Bool

    enum ListTab: String, CaseIterable { case recent = "Recent", favorites = "Favorites" }

    var body: some View {
        NavigationStack {
            Group {
                if let draft = vm.editingEntry {
                    FoodEntryEditView(vm: vm, draft: draft, savedFoods: savedFoods) {
                        dismiss()
                    }
                } else {
                    searchContent
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.editingEntry != nil && vm.editingEntry?.existingEntryID == nil {
                        Button {
                            vm.editingEntry = nil
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    } else {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            BarcodeScannerView { barcode in
                showScanner = false
                vm.handleBarcode(barcode)
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddView(mealType: vm.selectedMealType) { calories, protein, name in
                if vm.quickAdd(calories: calories, protein: protein, name: name, mealType: vm.selectedMealType, modelContext: modelContext) != nil {
                    dismiss()
                }
            }
        }
        .alert(
            "Product Not Found",
            isPresented: Binding(
                get: { vm.pendingManualDraftForBarcode != nil },
                set: { if !$0 { vm.pendingManualDraftForBarcode = nil } }
            )
        ) {
            Button("Enter Manually") {
                vm.editingEntry = vm.pendingManualDraftForBarcode
                vm.pendingManualDraftForBarcode = nil
                vm.errorMessage = nil
            }
            Button("Scan Again") {
                vm.pendingManualDraftForBarcode = nil
                vm.errorMessage = nil
                showScanner = true
            }
            Button("Cancel", role: .cancel) {
                vm.pendingManualDraftForBarcode = nil
                vm.errorMessage = nil
            }
        } message: {
            Text(vm.errorMessage ?? "This product isn't in the food database yet.")
        }
    }

    private var title: String {
        guard let draft = vm.editingEntry else { return "Add Food" }
        return draft.existingEntryID == nil ? "Log Food" : "Edit Entry"
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: FDSpacing.sm) {
                HStack(spacing: FDSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.fdSecondaryLabel)
                    TextField("Search foods, e.g. greek yogurt", text: $vm.searchQuery)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .onSubmit { vm.searchFood() }
                    if !vm.searchQuery.isEmpty {
                        Button {
                            vm.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.fdSecondaryLabel)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(10)
                .background(Color.fdSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))

                Picker("Meal", selection: $vm.selectedMealType) {
                    ForEach(MealType.allCases, id: \.rawValue) { m in
                        Text(m.rawValue).tag(m.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: FDSpacing.sm) {
                    QuickActionButton(icon: "barcode.viewfinder", title: "Scan") { showScanner = true }
                    QuickActionButton(icon: "bolt.fill", title: "Quick Add") { showQuickAdd = true }
                    QuickActionButton(icon: "square.and.pencil", title: "Manual") { vm.startManualEntry() }
                }
            }
            .padding(FDSpacing.md)

            Divider()

            if vm.isSearching {
                Spacer()
                ProgressView(vm.searchQuery.isEmpty ? "Looking up barcode…" : "Searching…")
                Spacer()
            } else if !vm.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                searchResults
            } else {
                historyLists
            }
        }
        // Search as the user types, after a short pause
        .task(id: vm.searchQuery) {
            let query = vm.searchQuery.trimmingCharacters(in: .whitespaces)
            guard query.count >= 3 else { return }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            vm.searchFood()
        }
        .overlay(alignment: .bottom) {
            if let loggedName {
                ToastView(message: "Logged \(loggedName)")
                    .padding(.bottom, FDSpacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if let error = vm.errorMessage, vm.searchResults.isEmpty {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text(error)
            } actions: {
                Button("Enter Manually") {
                    var draft = FoodViewModel.FoodEntryDraft(name: vm.searchQuery, mealType: vm.selectedMealType)
                    draft.name = vm.searchQuery.capitalized
                    vm.editingEntry = draft
                }
                .buttonStyle(.borderedProminent)
                .tint(.fdGreen)
            }
        } else if vm.searchResults.isEmpty {
            ContentUnavailableView("Keep typing…", systemImage: "text.cursor", description: Text("Results appear after a short pause. Press Search to look up now."))
        } else {
            List(vm.searchResults) { product in
                FoodSearchResultRow(product: product) {
                    vm.selectProduct(product)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var historyLists: some View {
        let recents = FoodViewModel.recentFoods(from: allEntries)
        VStack(spacing: 0) {
            Picker("List", selection: $tab) {
                ForEach(ListTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, FDSpacing.md)
            .padding(.vertical, FDSpacing.sm)

            switch tab {
            case .recent:
                if recents.isEmpty {
                    ContentUnavailableView(
                        "No Recent Foods",
                        systemImage: "clock",
                        description: Text("Foods you log appear here so you can add them again in one tap.")
                    )
                } else {
                    List(recents) { entry in
                        HistoryFoodRow(
                            name: entry.name,
                            detail: [entry.brand, entry.amountLabel].filter { !$0.isEmpty }.joined(separator: " · "),
                            calories: Int(entry.totalCalories),
                            onOpen: { vm.startFromRecent(entry) },
                            onQuickLog: {
                                _ = vm.relog(entry, mealType: vm.selectedMealType, modelContext: modelContext)
                                Haptics.success()
                                flash(entry.name)
                            }
                        )
                    }
                    .listStyle(.plain)
                }
            case .favorites:
                if savedFoods.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "star",
                        description: Text("Swipe right on a logged food, or tap the star while logging, to save it here.")
                    )
                } else {
                    List {
                        ForEach(savedFoods) { saved in
                            HistoryFoodRow(
                                name: saved.name,
                                detail: [saved.brand, FoodEntry.amountLabel(amount: saved.defaultAmount, unit: saved.servingDescription)]
                                    .filter { !$0.isEmpty }.joined(separator: " · "),
                                calories: Int(saved.totalCalories),
                                onOpen: { vm.startFromSaved(saved) },
                                onQuickLog: {
                                    _ = vm.relog(saved, mealType: vm.selectedMealType, modelContext: modelContext)
                                    flash(saved.name)
                                }
                            )
                        }
                        .onDelete { offsets in
                            offsets.map { savedFoods[$0] }.forEach { modelContext.delete($0) }
                            modelContext.saveOrLog()
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private func flash(_ name: String) {
        withAnimation { loggedName = name }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { if loggedName == name { loggedName = nil } }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.fdCaption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundColor(.fdGreen)
            .background(Color.fdGreen.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
        }
        .buttonStyle(.plain)
    }
}

struct HistoryFoodRow: View {
    let name: String
    let detail: String
    let calories: Int
    let onOpen: () -> Void
    let onQuickLog: () -> Void

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            Button(action: onOpen) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.fdSubheadline)
                            .foregroundColor(.fdLabel)
                            .lineLimit(1)
                        Text(detail)
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(calories) kcal")
                        .font(.fdSubheadline)
                        .foregroundColor(.fdSecondaryLabel)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onQuickLog) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.fdGreen)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log \(name) again")
        }
        .padding(.vertical, 2)
    }
}

struct FoodSearchResultRow: View {
    let product: OFFProduct
    let onSelect: () -> Void

    var calories: Int { Int(product.nutriments?.energyKcal100g ?? 0) }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FDSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.fdSubheadline)
                        .foregroundColor(.fdLabel)
                        .lineLimit(2)
                    let detail = [product.displayBrand, product.servingSize.map { "serving \($0)" } ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · ")
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(calories)")
                        .font(.fdHeadline)
                        .foregroundColor(.fdLabel)
                    Text("kcal/100g")
                        .font(.fdCaption2)
                        .foregroundColor(.fdSecondaryLabel)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Add

struct QuickAddView: View {
    let mealType: String
    let onAdd: (Double, Double, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var calories: Double? = nil
    @State private var protein: Double? = nil
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focused)
                        Text("kcal").foregroundColor(.fdSecondaryLabel)
                    }
                    HStack {
                        Text("Protein (optional)")
                        Spacer()
                        TextField("0", value: $protein, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("g").foregroundColor(.fdSecondaryLabel)
                    }
                    TextField("Description (optional)", text: $name)
                } footer: {
                    Text("Adds to \(mealType.lowercased()). Use this when you only know the calories, like a restaurant meal.")
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(calories ?? 0, protein ?? 0, name)
                        dismiss()
                    }
                    .disabled((calories ?? 0) <= 0)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Food Entry Edit

struct FoodEntryEditView: View {
    @ObservedObject var vm: FoodViewModel
    @State var draft: FoodViewModel.FoodEntryDraft
    let savedFoods: [SavedFood]
    let onDone: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var saveAsFavorite = false

    init(vm: FoodViewModel, draft: FoodViewModel.FoodEntryDraft, savedFoods: [SavedFood], onDone: @escaping () -> Void) {
        self.vm = vm
        _draft = State(initialValue: draft)
        self.savedFoods = savedFoods
        self.onDone = onDone
        let key = FoodEntry.matchKey(name: draft.name, brand: draft.brand)
        _saveAsFavorite = State(initialValue: savedFoods.contains { $0.matchKey == key })
    }

    private var gramChips: [Double] {
        var chips: [Double] = []
        if let typical = draft.typicalServingG, typical > 0 { chips.append(typical) }
        for g in [50.0, 100, 150, 200] where !chips.contains(g) { chips.append(g) }
        return chips
    }

    var body: some View {
        Form {
            Section("Food") {
                TextField("Name", text: $draft.name)
                    .font(.fdHeadline)
                TextField("Brand (optional)", text: $draft.brand)
                Picker("Meal", selection: $draft.mealType) {
                    ForEach(MealType.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
            }

            Section {
                Picker("Measure in", selection: $draft.basis) {
                    Text("Grams").tag(FoodViewModel.FoodEntryDraft.Basis.per100g)
                    Text("Servings").tag(FoodViewModel.FoodEntryDraft.Basis.perServing)
                }
                .pickerStyle(.segmented)

                if draft.basis == .per100g {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("100", value: $draft.quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("g").foregroundColor(.fdSecondaryLabel)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FDSpacing.sm) {
                            ForEach(gramChips, id: \.self) { grams in
                                let isTypical = grams == draft.typicalServingG
                                Button {
                                    draft.quantity = grams
                                    Haptics.selection()
                                } label: {
                                    Text(isTypical ? "1 serving (\(NumberFormatting.decimal(grams, maxFractionDigits: 0)) g)" : "\(NumberFormatting.decimal(grams, maxFractionDigits: 0)) g")
                                        .font(.fdCaption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(draft.quantity == grams ? Color.fdGreen : Color.fdGreen.opacity(0.12))
                                        .foregroundColor(draft.quantity == grams ? .white : .fdGreen)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Stepper(value: $draft.quantity, in: 0.25...50, step: 0.25) {
                        HStack {
                            Text("Servings")
                            Spacer()
                            Text(NumberFormatting.decimal(draft.quantity, maxFractionDigits: 2))
                                .font(.fdHeadline)
                                .monospacedDigit()
                        }
                    }
                    TextField("Serving name, e.g. slice, cup", text: $draft.servingLabel)
                }
            } header: {
                Text("Amount")
            }

            Section {
                NutritionInputRow(label: "Calories", value: $draft.calories, unit: "kcal", color: .fdOrange)
                NutritionInputRow(label: "Protein", value: $draft.protein, unit: "g", color: .fdBlue)
                NutritionInputRow(label: "Carbs", value: $draft.carbs, unit: "g", color: .fdYellow)
                NutritionInputRow(label: "Fat", value: $draft.fat, unit: "g", color: .fdPurple)
                NutritionInputRow(label: "Fiber", value: $draft.fiber, unit: "g", color: .fdGreen)
            } header: {
                Text(draft.basis == .per100g ? "Nutrition per 100 g" : "Nutrition per serving")
            }

            Section("You're logging") {
                HStack(spacing: FDSpacing.md) {
                    NutritionTotal(label: "Calories", value: draft.totalCalories, unit: "kcal", color: .fdOrange)
                    NutritionTotal(label: "Protein", value: draft.totalProtein, unit: "g", color: .fdBlue)
                    NutritionTotal(label: "Carbs", value: draft.totalCarbs, unit: "g", color: .fdYellow)
                    NutritionTotal(label: "Fat", value: draft.totalFat, unit: "g", color: .fdPurple)
                }
                Toggle(isOn: $saveAsFavorite) {
                    Label("Save to Favorites", systemImage: "star")
                }
                .tint(.fdYellow)
            }

            Section {
                Button {
                    save()
                } label: {
                    Text(draft.existingEntryID == nil ? "Log Food" : "Save Changes")
                        .font(.fdHeadline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(!draft.isValid)
                .listRowBackground(draft.isValid ? Color.fdGreen : Color.fdGreen.opacity(0.4))
                .foregroundColor(.white)

                if let id = draft.existingEntryID {
                    Button("Delete Entry", role: .destructive) {
                        if let entry = modelContext.model(for: id) as? FoodEntry {
                            vm.delete(entry, modelContext: modelContext)
                        }
                        vm.editingEntry = nil
                        onDone()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: draft.basis) { old, new in
            // Keep the amount sensible when switching measurement
            if old == .perServing && new == .per100g { draft.quantity = draft.typicalServingG ?? 100 }
            if old == .per100g && new == .perServing { draft.quantity = 1 }
        }
    }

    private func save() {
        guard let entry = vm.save(draft, modelContext: modelContext) else { return }
        let key = entry.matchKey
        let existing = savedFoods.filter { $0.matchKey == key }
        if saveAsFavorite && existing.isEmpty {
            modelContext.insert(SavedFood(from: entry))
        } else if !saveAsFavorite {
            existing.forEach { modelContext.delete($0) }
        } else {
            // Keep the favorite in sync with the latest amount and nutrition
            existing.forEach { modelContext.delete($0) }
            modelContext.insert(SavedFood(from: entry))
        }
        modelContext.saveOrLog()
        onDone()
    }
}

struct NutritionInputRow: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.fdSubheadline)
                .foregroundColor(.fdLabel)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.fdSubheadline)
                .frame(width: 80)
            Text(unit)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .frame(width: 32, alignment: .leading)
        }
    }
}

struct NutritionTotal: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f", value))
                .font(.fdHeadline)
                .foregroundColor(color)
                .monospacedDigit()
            Text(unit)
                .font(.fdCaption2)
                .foregroundColor(.fdSecondaryLabel)
            Text(label)
                .font(.fdCaption2)
                .foregroundColor(.fdSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }
}
