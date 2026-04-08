import SwiftUI
import SwiftData

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
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
                .padding(.vertical, FDSpacing.lg)

                // Content card
                VStack {
                    Spacer()
                    Group {
                        switch vm.currentStep {
                        case 0: OnboardingStepName(vm: vm)
                        case 1: OnboardingStepWeight(vm: vm)
                        case 2: OnboardingStepDate(vm: vm)
                        case 3: OnboardingStepActivity(vm: vm)
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

// MARK: - Step 2: Weight

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

            if let cw = Double(vm.currentWeight), let gw = Double(vm.goalWeight), cw > 0, gw > 0 {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Goal: lose \(String(format: "%.1f", max(0, cw - gw))) kg")
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

// MARK: - Step 3: Goal Date

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
                in: Date().addingTimeInterval(86400 * 7)...,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .colorScheme(.dark)
            .labelsHidden()

            if !vm.currentWeight.isEmpty, !vm.goalWeight.isEmpty {
                VStack(alignment: .leading, spacing: FDSpacing.sm) {
                    HStack {
                        Image(systemName: "flame.fill").foregroundColor(.fdOrange)
                        Text("Daily target: ~\(vm.estimatedCalories) kcal")
                            .font(.fdSubheadline)
                            .foregroundColor(.white)
                    }
                    Text("Based on your weight and goal date")
                        .font(.fdCaption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(FDSpacing.md)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.md))
            }
        }
        .padding(FDSpacing.xl)
    }
}

// MARK: - Step 4: Activity Level

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

            if !vm.currentWeight.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.fdGreen)
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
