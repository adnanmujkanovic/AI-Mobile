import SwiftUI
import SwiftData

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
        ZStack {
            LinearGradient.fdPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: FDSpacing.sm) {
                    HStack {
                        if vm.currentStep > 0 {
                            Button {
                                vm.previousStep()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                        Text("Step \(vm.currentStep + 1) of \(vm.totalSteps)")
                            .font(.fdSubheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, FDSpacing.lg)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(height: 4)
                            Capsule()
                                .fill(.white)
                                .frame(width: geo.size.width * (Double(vm.currentStep + 1) / Double(vm.totalSteps)), height: 4)
                                .animation(.easeInOut, value: vm.currentStep)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, FDSpacing.lg)
                }
                .padding(.top, FDSpacing.lg)

                // App Logo
                VStack(spacing: FDSpacing.sm) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                    Text("FitDrop")
                        .font(.fdLargeTitle)
                        .foregroundColor(.white)
                }
                .padding(.vertical, FDSpacing.md)

                // Content card
                VStack {
                    Spacer()
                    Group {
                        switch vm.currentStep {
                        case 0: OnboardingStepName(vm: vm)
                        case 1: OnboardingStepBody(vm: vm)
                        case 2: OnboardingStepWeight(vm: vm)
                        case 3: OnboardingStepDate(vm: vm)
                        case 4: OnboardingStepActivity(vm: vm)
                        default: EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(.horizontal, FDSpacing.md)

                Spacer(minLength: FDSpacing.lg)

                // CTA Button
                Group {
                    if vm.currentStep < vm.totalSteps - 1 {
                        Button {
                            vm.nextStep()
                        } label: {
                            Text("Continue")
                                .font(.fdHeadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(vm.isCurrentStepValid ? .white : .white.opacity(0.4))
                                .foregroundColor(vm.isCurrentStepValid ? .fdGreen : .white.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
                        }
                        .disabled(!vm.isCurrentStepValid)
                        .accessibilityIdentifier("onboardingContinue")
                    } else {
                        Button {
                            vm.completeOnboarding(modelContext: modelContext)
                        } label: {
                            HStack {
                                if vm.isCompleting {
                                    ProgressView().tint(.fdGreen)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Let's Go!")
                                        .font(.fdHeadline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white)
                            .foregroundColor(.fdGreen)
                            .clipShape(RoundedRectangle(cornerRadius: FDRadius.lg))
                        }
                    }
                }
                .padding(.horizontal, FDSpacing.lg)
                .padding(.bottom, FDSpacing.xl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .keyboardDoneButton()
        }
    }
}

// MARK: - Step 1: Name

struct OnboardingStepName: View {
    @ObservedObject var vm: OnboardingViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.lg) {
            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("Welcome!")
                    .font(.fdLargeTitle)
                    .foregroundColor(.white)
                Text("What should we call you?")
                    .font(.fdBody)
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("YOUR NAME")
                    .font(.fdCaption)
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1)
                TextField("e.g. Alex", text: $vm.name)
                    .font(.fdTitle2)
                    .foregroundColor(.white)
                    .focused($focused)
                    .submitLabel(.continue)
                    .onSubmit { if vm.isCurrentStepValid { vm.nextStep() } }
                Divider().background(.white.opacity(0.5))
            }
        }
        .padding(FDSpacing.xl)
        .onAppear { focused = true }
    }
}

// MARK: - Step 2: About You

struct OnboardingStepBody: View {
    @ObservedObject var vm: OnboardingViewModel
    @FocusState private var heightFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.lg) {
            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("About You")
                    .font(.fdLargeTitle)
                    .foregroundColor(.white)
                Text("Used to calculate how many calories your body burns")
                    .font(.fdBody)
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("SEX")
                    .font(.fdCaption)
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1)
                HStack(spacing: FDSpacing.sm) {
                    ForEach(Sex.allCases, id: \.rawValue) { option in
                        Button {
                            vm.sex = option
                            Haptics.selection()
                        } label: {
                            Text(option.displayName)
                                .font(.fdHeadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(vm.sex == option ? .white : .white.opacity(0.15))
                                .foregroundColor(vm.sex == option ? .fdGreen : .white)
                                .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
                        }
                        .accessibilityAddTraits(vm.sex == option ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("AGE")
                    .font(.fdCaption)
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1)
                Stepper(value: $vm.age, in: 16...100) {
                    Text("\(vm.age) years")
                        .font(.fdTitle2)
                        .foregroundColor(.white)
                }
                .colorScheme(.dark)
            }

            WeightInputField(label: "HEIGHT", value: $vm.heightCm, unit: "cm", focused: heightFocused)
                .focused($heightFocused)
        }
        .padding(FDSpacing.xl)
    }
}

// MARK: - Step 3: Weight

struct OnboardingStepWeight: View {
    @ObservedObject var vm: OnboardingViewModel
    @FocusState private var focusedField: WeightField?
    enum WeightField { case current, goal }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.lg) {
            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("Your Weight")
                    .font(.fdLargeTitle)
                    .foregroundColor(.white)
                Text("We'll calculate your daily calorie target")
                    .font(.fdBody)
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(spacing: FDSpacing.lg) {
                WeightInputField(
                    label: "CURRENT WEIGHT",
                    value: $vm.currentWeight,
                    unit: "kg",
                    focused: focusedField == .current
                )
                .focused($focusedField, equals: .current)

                WeightInputField(
                    label: "GOAL WEIGHT",
                    value: $vm.goalWeight,
                    unit: "kg",
                    focused: focusedField == .goal
                )
                .focused($focusedField, equals: .goal)
            }

            if let message = vm.weightValidationMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.fdSubheadline)
                    .foregroundColor(.white)
                    .padding(FDSpacing.sm)
                    .background(Color.fdOrange.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))
            } else if vm.weightToLose > 0 {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Goal: lose \(NumberFormatting.decimal(vm.weightToLose)) kg")
                }
                .font(.fdSubheadline)
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, FDSpacing.sm)
            }
        }
        .padding(FDSpacing.xl)
        .onAppear { focusedField = .current }
    }
}

struct WeightInputField: View {
    let label: String
    @Binding var value: String
    let unit: String
    let focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            Text(label)
                .font(.fdCaption)
                .foregroundColor(.white.opacity(0.7))
                .tracking(1)
            HStack {
                TextField("0.0", text: $value)
                    .font(.fdTitle2)
                    .foregroundColor(.white)
                    .keyboardType(.decimalPad)
                Text(unit)
                    .font(.fdTitle3)
                    .foregroundColor(.white.opacity(0.7))
            }
            Divider().background(focused ? .white : .white.opacity(0.4))
        }
    }
}

// MARK: - Step 4: Goal Date

struct OnboardingStepDate: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.lg) {
            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("Target Date")
                    .font(.fdLargeTitle)
                    .foregroundColor(.white)
                Text("When do you want to reach your goal?")
                    .font(.fdBody)
                    .foregroundColor(.white.opacity(0.8))
            }

            DatePicker(
                "",
                selection: $vm.goalDate,
                in: Date().addingTimeInterval(86400 * 14)...,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .colorScheme(.dark)
            .labelsHidden()

            if vm.weightToLose > 0 {
                VStack(alignment: .leading, spacing: FDSpacing.sm) {
                    HStack {
                        Image(systemName: "chart.line.downtrend.xyaxis").foregroundColor(.white)
                        Text("That's \(NumberFormatting.decimal(vm.requiredWeeklyLoss, maxFractionDigits: 2)) kg per week")
                            .font(.fdSubheadline)
                            .foregroundColor(.white)
                    }
                    if vm.requiredWeeklyLoss > 1 {
                        Text("Faster than the 0.5–1 kg/week experts recommend. We'll cap your deficit at a safe level, so it may take a little longer.")
                            .font(.fdCaption)
                            .foregroundColor(.white.opacity(0.85))
                        Button("Use a sustainable date") {
                            vm.goalDate = vm.recommendedGoalDate
                        }
                        .font(.fdCaption.weight(.semibold))
                        .foregroundColor(.white)
                        .underline()
                    }
                }
                .padding(FDSpacing.md)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
            }
        }
        .padding(FDSpacing.xl)
    }
}

// MARK: - Step 5: Activity Level

struct OnboardingStepActivity: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.lg) {
            VStack(alignment: .leading, spacing: FDSpacing.sm) {
                Text("Activity Level")
                    .font(.fdLargeTitle)
                    .foregroundColor(.white)
                Text("How active are you currently?")
                    .font(.fdBody)
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(spacing: FDSpacing.sm) {
                ForEach(ActivityLevel.allCases, id: \.rawValue) { level in
                    ActivityLevelRow(
                        level: level,
                        isSelected: vm.activityLevel == level
                    ) {
                        vm.activityLevel = level
                    }
                }
            }

            if vm.currentWeightDouble != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
                    Text("Daily target: ~\(vm.estimatedCalories) kcal")
                        .font(.fdSubheadline)
                        .foregroundColor(.white)
                }
                .padding(.top, FDSpacing.sm)
            }
        }
        .padding(FDSpacing.xl)
    }
}

struct ActivityLevelRow: View {
    let level: ActivityLevel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FDSpacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .fdGreen : .white.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.fdSubheadline)
                        .foregroundColor(.white)
                    Text(level.description)
                        .font(.fdCaption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(FDSpacing.md)
            .background(isSelected ? .white.opacity(0.2) : .white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: FDRadius.md)
                    .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
            )
        }
    }
}
