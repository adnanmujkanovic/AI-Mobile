import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.openURL) private var openURL

    @State private var exportedFiles: [URL] = []
    @State private var exportError: String? = nil
    @State private var confirmReset = false
    @State private var goalWeightText = ""
    @State private var heightText = ""
    @State private var aiKeyConfigured = AIFoodAnalyzer.isConfigured
    @State private var aiKeyInput = ""

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                goalsSection
                targetsSection
                fastingSection
                remindersSection
                healthSection
                aiSection
                dataSection
                aboutSection
            }
            .keyboardDoneButton()
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitTextFields()
                        modelContext.saveOrLog()
                        dismiss()
                    }
                }
            }
            .onAppear {
                goalWeightText = NumberFormatting.decimal(profile.goalWeight)
                heightText = NumberFormatting.decimal(profile.heightCm, maxFractionDigits: 0)
                Task { await notifications.checkStatus() }
            }
            .onChange(of: profile.sex) { recalculate() }
            .onChange(of: profile.age) { recalculate() }
            .onChange(of: profile.activityLevel) { recalculate() }
            .onChange(of: profile.goalDate) { recalculate() }
            .onChange(of: profile.useCustomCalorieTarget) { recalculate() }
            .alert("Export Failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "")
            }
            .confirmationDialog("Delete all FitDrop data?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    do {
                        try DataExporter.deleteAll(context: modelContext)
                        dismiss()
                    } catch {
                        exportError = "Couldn't delete data: \(error.localizedDescription)"
                    }
                }
            } message: {
                Text("This removes your profile, logs and history from this iPhone. Data already saved to Apple Health stays there. This can't be undone.")
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name", text: $profile.name)
            Picker("Sex", selection: $profile.sex) {
                ForEach(Sex.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
            }
            Stepper(value: $profile.age, in: 16...100) {
                LabeledContent("Age", value: "\(profile.age)")
            }
            HStack {
                Text("Height")
                Spacer()
                TextField("170", text: $heightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onSubmit(commitTextFields)
                Text("cm").foregroundColor(.fdSecondaryLabel)
            }
            Picker("Activity", selection: $profile.activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.rawValue) { Text($0.displayName).tag($0.rawValue) }
            }
        }
    }

    private var goalsSection: some View {
        Section {
            LabeledContent("Current weight", value: "\(NumberFormatting.decimal(profile.currentWeight)) kg")
            HStack {
                Text("Goal weight")
                Spacer()
                TextField("65", text: $goalWeightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onSubmit(commitTextFields)
                Text("kg").foregroundColor(.fdSecondaryLabel)
            }
            DatePicker("Goal date", selection: $profile.goalDate, in: Date()..., displayedComponents: .date)
        } header: {
            Text("Goal")
        } footer: {
            Text("Current weight updates when you log your weight on the Today tab.")
        }
    }

    private var targetsSection: some View {
        Section {
            Toggle("Set my own calorie target", isOn: $profile.useCustomCalorieTarget)
                .tint(.fdGreen)
            if profile.useCustomCalorieTarget {
                Stepper(value: $profile.dailyCalorieTarget, in: 1000...5000, step: 50) {
                    LabeledContent("Daily calories", value: "\(profile.dailyCalorieTarget) kcal")
                }
            } else {
                LabeledContent("Daily calories", value: "\(profile.dailyCalorieTarget) kcal")
            }

            Stepper(value: proteinBinding, in: 40...300, step: 5) {
                LabeledContent("Protein", value: "\(profile.effectiveProteinGoalG) g" + (profile.proteinGoalG == 0 ? " (auto)" : ""))
            }
            Stepper(value: waterBinding, in: 1000...5000, step: 250) {
                LabeledContent("Water", value: NumberFormatting.liters(fromMl: profile.effectiveWaterGoalMl) + (profile.waterGoalMl == 0 ? " (auto)" : ""))
            }
            if profile.proteinGoalG != 0 || profile.waterGoalMl != 0 {
                Button("Use Recommended Protein & Water") {
                    profile.proteinGoalG = 0
                    profile.waterGoalMl = 0
                }
            }
        } header: {
            Text("Daily Targets")
        } footer: {
            Text("Calories use the Mifflin-St Jeor formula for your age, height, sex and activity, minus a safe deficit (at most 750 kcal/day). Protein defaults to 1.6 g per kg of goal weight; water to 35 ml per kg.")
        }
    }

    private var fastingSection: some View {
        Section {
            DatePicker("Usual start time", selection: fastStartBinding, displayedComponents: .hourAndMinute)
            Toggle("Daily reminder to start", isOn: $profile.fastStartReminderEnabled)
                .tint(.fdGreen)
            Toggle("Milestone alerts during a fast", isOn: $profile.fastMilestoneAlertsEnabled)
                .tint(.fdGreen)
        } header: {
            Text("Fasting")
        } footer: {
            Text("Milestone alerts tell you at 12h, 16h and 18h, one hour before your goal, and when you reach it.")
        }
        .onChange(of: profile.fastStartReminderEnabled) { applyNotifications() }
        .onChange(of: profile.fastMilestoneAlertsEnabled) { applyNotifications() }
    }

    private var remindersSection: some View {
        Section {
            if notifications.authorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Notifications are off. Turn them on in Settings.", systemImage: "bell.slash.fill")
                        .foregroundColor(.fdOrange)
                }
            } else if notifications.authorizationStatus == .notDetermined {
                Button {
                    Task {
                        await notifications.requestAuthorization()
                        applyNotifications()
                    }
                } label: {
                    Label("Allow Notifications", systemImage: "bell.badge.fill")
                }
            }
            Toggle("Evening food log reminder", isOn: $profile.foodReminderEnabled)
                .tint(.fdGreen)
            Toggle("Workout reminders (Mon, Wed, Fri)", isOn: $profile.workoutReminderEnabled)
                .tint(.fdGreen)
        } header: {
            Text("Reminders")
        }
        .onChange(of: profile.foodReminderEnabled) { applyNotifications() }
        .onChange(of: profile.workoutReminderEnabled) { applyNotifications() }
    }

    private var healthSection: some View {
        Section {
            if health.isAvailable {
                Toggle(isOn: Binding(
                    get: { health.isEnabled },
                    set: { on in
                        if on {
                            Task {
                                profile.healthKitEnabled = await health.enable()
                            }
                        } else {
                            health.disable()
                            profile.healthKitEnabled = false
                        }
                    }
                )) {
                    Label("Sync with Apple Health", systemImage: "heart.fill")
                }
                .tint(.fdRed)
                if let error = health.lastError {
                    Text(error).font(.fdCaption).foregroundColor(.fdRed)
                }
            } else {
                Text("Apple Health isn't available on this device.")
                    .foregroundColor(.fdSecondaryLabel)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Saves weight, water, food energy and macros, and workouts to Health. Reads steps and active energy to show what you burned. You can change exactly what's shared in the Health app.")
        }
    }

    private var aiSection: some View {
        Section {
            if aiKeyConfigured {
                Label("Claude API key saved", systemImage: "checkmark.seal.fill")
                    .foregroundColor(.fdGreen)
                Button("Remove Key", role: .destructive) {
                    KeychainStore.set(nil, for: AIFoodAnalyzer.apiKeyKeychainKey)
                    aiKeyConfigured = false
                }
            } else {
                SecureField("Paste Claude API key (sk-ant-…)", text: $aiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save Key") {
                    KeychainStore.set(aiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines), for: AIFoodAnalyzer.apiKeyKeychainKey)
                    aiKeyInput = ""
                    aiKeyConfigured = AIFoodAnalyzer.isConfigured
                    Haptics.success()
                }
                .disabled(!aiKeyInput.trimmingCharacters(in: .whitespaces).hasPrefix("sk-ant-"))
                Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                    Label("Get an API Key", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("AI Food Recognition")
        } footer: {
            Text("Recognizes food from a photo or description with Anthropic's Claude, for meals without barcodes. The key is stored only in this iPhone's Keychain. Photos are sent to Anthropic only when you use AI Photo.")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                do {
                    exportedFiles = try DataExporter.export(context: modelContext)
                } catch {
                    exportError = error.localizedDescription
                }
            } label: {
                Label("Prepare CSV Export", systemImage: "tablecells")
            }
            if !exportedFiles.isEmpty {
                ShareLink(items: exportedFiles) {
                    Label("Share \(exportedFiles.count) CSV Files", systemImage: "square.and.arrow.up")
                }
            }
            Button(role: .destructive) {
                confirmReset = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
            }
        } header: {
            Text("Your Data")
        } footer: {
            Text("Everything is stored only on this iPhone. There's no account and no server.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            Link(destination: URL(string: "https://world.openfoodfacts.org")!) {
                Label("Food data from Open Food Facts (ODbL)", systemImage: "leaf")
            }
        } header: {
            Text("About")
        } footer: {
            Text("FitDrop is not a medical device and doesn't give medical advice. Talk to a doctor before starting a diet, fasting or exercise program, especially if you have a health condition.")
        }
    }

    // MARK: - Bindings & Helpers

    /// Starts from the recommended value the first time the user adjusts it.
    private var proteinBinding: Binding<Int> {
        Binding(get: { profile.effectiveProteinGoalG }, set: { profile.proteinGoalG = $0 })
    }

    private var waterBinding: Binding<Int> {
        Binding(get: { profile.effectiveWaterGoalMl }, set: { profile.waterGoalMl = $0 })
    }

    private var fastStartBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: profile.fastingStartHour, minute: profile.fastingStartMinute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                profile.fastingStartHour = Calendar.current.component(.hour, from: date)
                profile.fastingStartMinute = Calendar.current.component(.minute, from: date)
                applyNotifications()
            }
        )
    }

    private func commitTextFields() {
        if let goal = NumberFormatting.parseDecimal(goalWeightText), (30...300).contains(goal), goal != profile.goalWeight {
            profile.goalWeight = goal
            recalculate()
        }
        if let height = NumberFormatting.parseDecimal(heightText), (100...250).contains(height), height != profile.heightCm {
            profile.heightCm = height
            recalculate()
        }
    }

    private func recalculate() {
        profile.recalculateCalorieTarget()
    }

    private func applyNotifications() {
        NotificationManager.shared.applyPreferences(from: profile)
    }
}
