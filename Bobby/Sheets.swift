import SwiftUI

// MARK: - Three questions, asked once, right when they matter

struct ProfileSheet: View {
    var auto = false
    var onDone: (InvestorProfile) -> Void
    @State private var risk = "按计划来"
    @State private var horizon = "几个月"
    @State private var size = 0.05

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("跟踪之前，先认识你").font(.serif(26, .medium))
                Text("回答三个问题，之后我写的每个计划都按你的习惯来。随时可以改。")
                    .font(.system(size: 14)).foregroundStyle(Theme.ink2)
            }
            Question(title: "交易和你预期相反时，你通常会…", options: ["果断止损", "按计划来", "扛过去"], selection: $risk)
            Question(title: "你通常持有多久？", options: ["几天", "几周", "几个月"], selection: $horizon)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("单个观点最多投入").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("\(Int(size * 100))% · \((size * 1_000_000).usd0)")
                        .font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.violet)
                        .contentTransition(.numericText())
                }
                Slider(value: $size, in: 0.01...0.20, step: 0.01).tint(Theme.violet)
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "保存并继续") {
                onDone(InvestorProfile(risk: risk, horizon: horizon, maxPosition: size))
            }
        }
        .padding(24)
        .padding(.top, 8)
        .task {
            guard auto else { return }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.snappy) { risk = "果断止损" }
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.snappy) { horizon = "几周" }
            try? await Task.sleep(for: .seconds(0.9))
            for v in [0.06, 0.07, 0.08] { withAnimation(.snappy) { size = v }; try? await Task.sleep(for: .milliseconds(180)) }
            try? await Task.sleep(for: .seconds(1.0))
            onDone(InvestorProfile(risk: risk, horizon: horizon, maxPosition: size))
        }
    }
}

struct Question: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .semibold))
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { o in
                    Button {
                        withAnimation(.snappy) { selection = o }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(o).font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selection == o ? .white : Theme.ink)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(Capsule().fill(selection == o ? Theme.ink : Color.black.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Paper order: the plan, sized to the profile, no account wall

struct PaperOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let thesis: Thesis
    let profile: InvestorProfile
    let cash: Double
    var auto = false
    var onPlace: (Int) -> Void
    @State private var placed = false

    var budget: Double { cash * profile.maxPosition }
    func shares(for leg: PlanLeg) -> Int { Int((budget * leg.weight / leg.price).rounded(.down)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Capsule().fill(Theme.ink3.opacity(0.4)).frame(width: 36, height: 5).frame(maxWidth: .infinity)
            if placed { success } else { form }
        }
        .padding(24)
        .background(Theme.bg)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "flask").foregroundStyle(Theme.violet)
                Text("模拟账户 · \(cash.usd0)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.violet)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Theme.violet.opacity(0.08)))

            VStack(alignment: .leading, spacing: 4) {
                Text("分 3 档买入 \(thesis.ticker)").font(.serif(28, .medium))
                Text("按你设的单个观点上限 \(Int(profile.maxPosition * 100))%（\(budget.usd0)）计算。第 2、3 档挂限价单，观点被证伪时自动撤单。")
                    .font(.system(size: 14)).foregroundStyle(Theme.ink2)
            }

            VStack(spacing: 0) {
                ForEach(Array(thesis.plan.enumerated()), id: \.element.id) { i, leg in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(i == 0 ? "第 1 档 · 市价" : "第 \(i + 1) 档 · 限价 \(leg.price.usd0)")
                                .font(.system(size: 15, weight: .semibold))
                            Text(leg.note).font(.system(size: 12)).foregroundStyle(Theme.ink3)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(shares(for: leg)) 股").font(.system(size: 15, weight: .semibold).monospacedDigit())
                            Text((Double(shares(for: leg)) * leg.price).usd0).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.ink3)
                        }
                    }
                    .padding(.vertical, 14)
                    if i < thesis.plan.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 16)
            .card(20)

            VStack(alignment: .leading, spacing: 10) {
                Label("日线收盘跌破 \(thesis.stop.usd) 自动离场", systemImage: "xmark.octagon")
                Label("触发止损最多亏 \(maxLoss.usd0)（占账户 \(String(format: "%.2f", maxLoss / cash * 100))%）", systemImage: "shield.lefthalf.filled")
            }
            .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink2)

            Spacer(minLength: 0)
            HoldToConfirm(title: "长按下模拟单", autoFire: auto) {
                onPlace(shares(for: thesis.plan[0]))
                withAnimation(.spring) { placed = true }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Text("想用真金白银？随时绑定 RockFlow 账户，观点和计划都会带过去。")
                .font(.system(size: 12)).foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private var maxLoss: Double {
        thesis.plan.reduce(0) { $0 + Double(shares(for: $1)) * max(0, $1.price - thesis.stop) }
    }

    private var success: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Theme.up.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "checkmark").font(.system(size: 40, weight: .bold)).foregroundStyle(Theme.up)
            }
            .transition(.scale.combined(with: .opacity))
            Text("第 1 档已成交").font(.serif(28, .medium))
            Text("模拟盘买入 \(thesis.ticker) \(shares(for: thesis.plan[0])) 股 @ \(thesis.price.usd)。\n第 2、3 档在等待，我会盯着你的线。")
                .font(.system(size: 15)).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "完成") { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .task { if auto { try? await Task.sleep(for: .seconds(2.6)); dismiss() } }
    }
}

struct HoldToConfirm: View {
    let title: String
    var autoFire = false
    var onConfirm: () -> Void
    @State private var progress: CGFloat = 0
    @State private var holding = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ink)
                Capsule().fill(Theme.brand).frame(width: geo.size.width * progress)
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 54)
        .contentShape(Capsule())
        .task {
            guard autoFire else { return }
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(.linear(duration: 0.9)) { progress = 1 }
            try? await Task.sleep(for: .seconds(0.95))
            onConfirm()
        }
        .onLongPressGesture(minimumDuration: 0.9, maximumDistance: 40) {
            onConfirm()
        } onPressingChanged: { pressing in
            if pressing {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.linear(duration: 0.9)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
    }
}
