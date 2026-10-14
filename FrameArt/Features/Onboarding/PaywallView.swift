import RevenueCat
import SwiftUI

/// Paywall con la misma composición que el de Clarity: ícono con resplandor, tagline en
/// versalitas, titular personalizado, filas de planes apiladas con insignia y precio a la
/// derecha, botón principal con brillo, aviso de renovación, Términos/Privacidad, Restaurar
/// y cierre suave (la X aparece tras unos segundos).
struct PaywallView: View {
    enum Source: String {
        case onboarding, settings, publishLimit = "publish_limit"
    }

    let source: Source
    var pain: OnboardingPainID?
    /// Se llama al terminar: compra, restauración o cierre suave.
    var onFinish: () -> Void

    @State private var subscriptions = SubscriptionManager.shared
    @State private var selectedPackageID: String?
    @State private var showClose = false
    @State private var purchasing = false
    @State private var didAppear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Segundos antes de mostrar la X (Clarity: `softPaywallCloseDelaySeconds`). Desde ajustes, inmediata.
    static let softCloseDelay: Double = 4

    private let termsURL = URL(string: "https://frame-studio.netlify.app/terms/")!
    private let privacyURL = URL(string: "https://frame-studio.netlify.app/privacy/")!

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FrameStudioBrand.canvas.ignoresSafeArea()

            OnboardingScreenFrame {
                VStack(spacing: 0) {
                    OnboardingHeroAppIcon(size: 112, glowSize: 162, cornerRadius: 26, animated: true)
                        .modifier(PaywallEntrance(visible: didAppear, order: 0, reduceMotion: reduceMotion))

                    Spacer().frame(height: 16)

                    Text("FRAME STUDIO PRO")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(FrameStudioBrand.blue)
                        .modifier(PaywallEntrance(visible: didAppear, order: 1, reduceMotion: reduceMotion))

                    Spacer().frame(height: 12)

                    OnboardingTitle(text: headline)
                        .modifier(PaywallEntrance(visible: didAppear, order: 2, reduceMotion: reduceMotion))

                    Spacer().frame(height: 10)

                    benefits
                        .modifier(PaywallEntrance(visible: didAppear, order: 3, reduceMotion: reduceMotion))

                    Spacer().frame(height: 20)

                    planSection
                        .modifier(PaywallEntrance(visible: didAppear, order: 4, reduceMotion: reduceMotion))

                    Spacer().frame(height: 14)

                    OnboardingPrimaryButton(title: purchaseTitle, enabled: selectedPackage != nil && !purchasing) {
                        Task { await purchase() }
                    }
                    .background { PaywallButtonGlow(active: !reduceMotion).padding(.horizontal, 24) }

                    Text(disclosure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340, minHeight: 34, alignment: .top)
                        .padding(.top, 10)

                    HStack(spacing: 16) {
                        Link("Términos", destination: termsURL)
                        Link("Privacidad", destination: privacyURL)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                    OnboardingSecondaryButton(title: "Restaurar compras") {
                        Task { await restore() }
                    }
                    .padding(.top, 8)
                }
            }

            if showClose {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(FrameStudioBrand.softLavender, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")
                .padding(.top, 14)
                .padding(.trailing, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .tint(FrameStudioBrand.accent)
        .task {
            Analytics.log(.paywallViewed(source: source.rawValue))
            await subscriptions.loadOfferings()
            if selectedPackageID == nil {
                // Igual que Clarity, se preselecciona el plan con prueba (anual).
                selectedPackageID = (subscriptions.offering?.annual ?? packages.first)?.identifier
            }
        }
        .task {
            let delay = source == .settings ? 0 : Self.softCloseDelay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            withAnimation(.easeInOut(duration: 0.18)) { showClose = true }
        }
        .onAppear { didAppear = true }
        .onChange(of: subscriptions.isPro) { _, isPro in
            if isPro { onFinish() }
        }
        .alert("Frame Studio Pro", isPresented: Binding(
            get: { subscriptions.errorMessage != nil },
            set: { if !$0 { subscriptions.errorMessage = nil } }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(subscriptions.errorMessage ?? "")
        }
    }

    // MARK: Contenido

    private var headline: String {
        if source == .publishLimit {
            return "Publica todas\ntus obras"
        }
        return (pain ?? .wall).paywallHeadline
    }

    /// Gratis vs Pro (Guideline 3.1.2(c): decir claramente qué se obtiene por el precio).
    private var benefits: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                Text("")
                Text("Gratis").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    .gridColumnAlignment(.center)
                Text("Pro").font(.footnote.weight(.bold)).foregroundStyle(FrameStudioBrand.accent)
                    .gridColumnAlignment(.center)
            }
            Divider().gridCellUnsizedAxes(.horizontal)
            comparisonRow("Enlaces publicados para clientes", free: "\(ProPlan.freePublishedLimit)", pro: "Ilimitados")
            comparisonRow("Obras en tu taller", free: "Ilimitadas", pro: "Ilimitadas")
            comparisonRow("Prueba en AR a tamaño real", free: nil, pro: nil)
            comparisonRow("Aviso cuando tu cliente abre", free: nil, pro: nil)
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }

    /// `nil` = incluido (✓).
    private func comparisonRow(_ title: String, free: String?, pro: String?) -> some View {
        GridRow {
            Text(title).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            cell(free, emphasized: false)
            cell(pro, emphasized: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). Gratis: \(free ?? "incluido"). Pro: \(pro ?? "incluido").")
    }

    @ViewBuilder
    private func cell(_ value: String?, emphasized: Bool) -> some View {
        if let value {
            Text(value)
                .font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(emphasized ? FrameStudioBrand.accent : .secondary)
                .multilineTextAlignment(.center)
        } else {
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(emphasized ? FrameStudioBrand.accent : .secondary)
        }
    }

    private var packages: [Package] {
        guard let offering = subscriptions.offering else { return [] }
        let order: [PackageType] = [.annual, .monthly, .lifetime]
        return offering.availablePackages.sorted {
            (order.firstIndex(of: $0.packageType) ?? 9) < (order.firstIndex(of: $1.packageType) ?? 9)
        }
    }

    private var selectedPackage: Package? {
        packages.first { $0.identifier == selectedPackageID }
    }

    @ViewBuilder
    private var planSection: some View {
        if !subscriptions.isConfigured {
            notConfigured
        } else if packages.isEmpty {
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { _ in Color.clear.frame(height: 64) }
            }
            .overlay { ProgressView("Cargando") }
            .padding(.horizontal, 24)
        } else {
            VStack(spacing: 10) {
                ForEach(packages, id: \.identifier) { package in
                    PaywallPlanRow(package: package, selected: package.identifier == selectedPackageID) {
                        if selectedPackageID != package.identifier {
                            UISelectionFeedbackGenerator().selectionChanged()
                            Analytics.log(.paywallPlanSelected(productID: package.storeProduct.productIdentifier))
                        }
                        selectedPackageID = package.identifier
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var notConfigured: some View {
        VStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver")
                .foregroundStyle(FrameStudioBrand.accent)
            #if DEBUG
            Text("RevenueCat no está configurado")
                .font(.subheadline.weight(.semibold))
            Text("Añade REVENUECAT_API_KEY en Config/Secrets.env y recompila.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #else
            Text("Los planes no están disponibles ahora.")
                .font(.subheadline.weight(.semibold))
            #endif
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(FrameStudioBrand.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }

    private var purchaseTitle: String {
        guard let package = selectedPackage else { return "Continuar" }
        if package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial {
            return "Empezar prueba gratis"
        }
        return package.packageType == .lifetime ? "Comprar de por vida" : "Suscribirme"
    }

    private var disclosure: String {
        guard let package = selectedPackage else { return "Cancela cuando quieras desde Ajustes." }
        let price = package.storeProduct.localizedPriceString
        if package.packageType == .lifetime {
            return "Pago único de \(price). Sin renovación."
        }
        let period = package.packageType == .annual ? "año" : "mes"
        if let intro = package.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
            return "\(Self.describe(intro.subscriptionPeriod)) gratis, luego \(price) al \(period). Se renueva sola; cancela cuando quieras."
        }
        return "\(price) al \(period). Se renueva sola; cancela cuando quieras."
    }

    static func describe(_ period: SubscriptionPeriod) -> String {
        let n = period.value
        switch period.unit {
        case .day: return n == 1 ? "1 día" : "\(n) días"
        case .week: return n == 1 ? "1 semana" : "\(n) semanas"
        case .month: return n == 1 ? "1 mes" : "\(n) meses"
        case .year: return n == 1 ? "1 año" : "\(n) años"
        }
    }

    // MARK: Acciones

    private func purchase() async {
        guard let package = selectedPackage else { return }
        let id = package.storeProduct.productIdentifier
        purchasing = true
        defer { purchasing = false }
        Analytics.log(.paywallPurchaseStarted(productID: id))
        switch await subscriptions.purchase(package) {
        case .purchased:
            Analytics.log(.paywallPurchaseCompleted(productID: id))
            onFinish()
        case .cancelled:
            Analytics.log(.paywallPurchaseCancelled(productID: id))
        case .pending:
            subscriptions.errorMessage = "La compra está pendiente de aprobación."
        case .failed:
            Analytics.log(.paywallPurchaseFailed(productID: id))
        }
    }

    private func restore() async {
        let ok = await subscriptions.restore()
        Analytics.log(.paywallRestore(success: ok))
        if ok { onFinish() }
    }

    private func dismiss() {
        Analytics.log(.paywallDismissed(source: source.rawValue))
        onFinish()
    }
}

/// Fila de plan apilada (Clarity: `stackedPlanRow` + `PaywallPlanPriceColumn`).
struct PaywallPlanRow: View {
    let package: Package
    let selected: Bool
    let action: () -> Void

    private var title: String {
        switch package.packageType {
        case .annual: return "Anual"
        case .monthly: return "Mensual"
        case .lifetime: return "De por vida"
        default: return package.storeProduct.localizedTitle
        }
    }

    private var subtitle: String? {
        let product = package.storeProduct
        switch package.packageType {
        case .annual:
            if let monthly = product.localizedPricePerMonth { return "\(monthly) al mes" }
            return nil
        case .lifetime: return "Pago único"
        default: return "Flexible, cancela cuando quieras"
        }
    }

    private var badge: String? {
        if let intro = package.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
            return "\(PaywallView.describe(intro.subscriptionPeriod).uppercased()) GRATIS"
        }
        return package.packageType == .lifetime ? "SIN RENOVACIÓN" : nil
    }

    private var suffix: String? {
        switch package.packageType {
        case .annual: return "/año"
        case .monthly: return "/mes"
        default: return nil
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? FrameStudioBrand.accent : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .padding(.horizontal, 9).padding(.vertical, 3.5)
                            .background(FrameStudioBrand.buttonFill, in: Capsule())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(package.storeProduct.localizedPriceString)
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                        if let suffix {
                            Text(suffix).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .background(selected ? FrameStudioBrand.softLavender : FrameStudioBrand.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? FrameStudioBrand.accent.opacity(0.7) : Color(uiColor: .separator), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Brillo que respira detrás del botón principal (Clarity: `PaywallButtonGlow`).
struct PaywallButtonGlow: View {
    let active: Bool
    @State private var on = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(FrameStudioBrand.accent.opacity(on ? 0.35 : 0.15))
            .blur(radius: 14)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { on = true }
            }
            .allowsHitTesting(false)
    }
}

/// Entrada escalonada de la cabecera (Clarity: `PaywallEntrance`).
struct PaywallEntrance: ViewModifier {
    let visible: Bool
    let order: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 10)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(Double(order) * 0.07), value: visible)
    }
}
