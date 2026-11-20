import SwiftUI

struct ThesisCardView: View {
    @Bindable var thesis: Thesis
    var isTracked: Bool
    var onTrack: () -> Void
    var onTrade: () -> Void
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 8) {
                Text("观点卡").font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundStyle(Theme.brand)
                Text("·").foregroundStyle(Theme.ink3)
                Text(thesis.ticker).font(.system(size: 12, weight: .bold))
                Spacer()
                StatusBadge(status: isTracked ? thesis.status : .draft)
            }

            Text(thesis.claim)
                .font(.serif(21, .medium))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            OddsBlock(thesis: thesis, editable: !isTracked)

            Divider().opacity(0.6)

            // Plan
            VStack(alignment: .leading, spacing: 10) {
                BlockTitle(icon: "stairs", title: "执行计划", trailing: "分 3 档建仓")
                ForEach(Array(thesis.plan.enumerated()), id: \.element.id) { i, leg in
                    HStack(spacing: 10) {
                        Text("\(i + 1)").font(.mono(11)).foregroundStyle(Theme.ink2)
                            .frame(width: 22, height: 22).background(Circle().fill(Color.black.opacity(0.05)))
                        Text(leg.price.usd0).font(.system(size: 14, weight: .semibold).monospacedDigit()).frame(width: 52, alignment: .leading)
                        Text(leg.note).font(.system(size: 14)).foregroundStyle(Theme.ink2)
                        Spacer()
                        Text("\(Int(leg.weight * 100))%").font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.ink2)
                    }
                }
            }

            // Invalidation
            VStack(alignment: .leading, spacing: 10) {
                BlockTitle(icon: "xmark.octagon", title: "出现这些就说明我错了", trailing: nil, tint: Theme.down)
                ForEach(thesis.conditions.filter { $0.kind == .invalidation }) { c in
                    ConditionRow(condition: c, price: thesis.price)
                }
            }

            // Checkpoints
            VStack(alignment: .leading, spacing: 10) {
                BlockTitle(icon: "calendar.badge.checkmark", title: "检查日 \(thesis.checkpoints.first?.date ?? "")", trailing: nil, tint: Theme.violet)
                ForEach(thesis.checkpoints) { cp in
                    HStack {
                        Text(cp.metric).font(.system(size: 14))
                        Spacer()
                        Text(cp.expectation).font(.system(size: 14, weight: .semibold).monospacedDigit())
                    }
                }
            }

            // Actions
            if isTracked {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill").foregroundStyle(Theme.violet)
                        Text(thesis.position == nil
                             ? "跟踪中。碰到你的线或到了 2 月 16 日，我会提醒你。"
                             : "已用模拟仓跟踪。任何条件触发我都会提醒你。")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink2)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.violet.opacity(0.07)))
                    HStack(spacing: 10) {
                        SecondaryButton(title: "查看观点", icon: "arrow.up.right", action: onOpen)
                        if thesis.position == nil {
                            PrimaryButton(title: "模拟下单", icon: "flask", action: onTrade)
                        }
                    }
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 10) {
                    SecondaryButton(title: "模拟下单", icon: "flask", action: onTrade)
                    PrimaryButton(title: "跟踪观点", icon: "scope", action: onTrack)
                }
            }

            Text("这是你的观点，Bobby 负责记录和跟踪，不构成投资建议。")
                .font(.system(size: 11)).foregroundStyle(Theme.ink3)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.card)
                .shadow(color: Theme.violet.opacity(0.12), radius: 30, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(LinearGradient(colors: [Theme.violet.opacity(0.35), Theme.sky.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .animation(.spring, value: isTracked)
    }
}

struct BlockTitle: View {
    let icon: String
    let title: String
    let trailing: String?
    var tint: Color = Theme.ink
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 12)).foregroundStyle(Theme.ink3) }
        }
    }
}

struct ConditionRow: View {
    let condition: Condition
    let price: Double
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(condition.kind == .invalidation ? Theme.down : Theme.up).frame(width: 6, height: 6)
            Text(condition.text).font(.system(size: 14))
            Spacer()
            if let l = condition.level {
                let d = (price - l) / price * 100
                Text(String(format: "%@ · %.1f%%", l.usd, abs(d)))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(abs(d) < 1.5 ? Theme.amber : Theme.ink2)
            }
        }
    }
}

/// "你 vs 市场" — the edge, made visible.
struct OddsBlock: View {
    @Bindable var thesis: Thesis
    var editable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(thesis.marketQuestion).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ink2)
                Spacer()
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.05)).frame(height: 10)
                    Capsule().fill(Theme.ink3.opacity(0.45))
                        .frame(width: w * thesis.marketProbability, height: 10)
                    Capsule().fill(Theme.brand)
                        .frame(width: w * thesis.myProbability, height: 4)
                        .padding(.leading, 0)
                    Circle().fill(.white)
                        .overlay(Circle().stroke(Theme.violet, lineWidth: 3))
                        .frame(width: 20, height: 20)
                        .shadow(color: Theme.violet.opacity(0.3), radius: 6)
                        .offset(x: w * thesis.myProbability - 10)
                        .gesture(editable ? DragGesture(minimumDistance: 0).onChanged { v in
                            let p = (v.location.x / w).clamped(0.05, 0.95)
                            let snapped = (p * 100).rounded() / 100
                            if snapped != thesis.myProbability {
                                thesis.myProbability = snapped
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        } : nil)
                    Rectangle().fill(Theme.ink).frame(width: 2, height: 18)
                        .offset(x: w * thesis.marketProbability - 1)
                }
                .frame(height: 22)
            }
            .frame(height: 22)

            HStack(spacing: 0) {
                OddsStat(label: "你", value: thesis.myProbability.pct, tint: Theme.violet)
                Spacer()
                OddsStat(label: "市场", value: thesis.marketProbability.pct, tint: Theme.ink, sub: thesis.marketSource)
                Spacer()
                let e = thesis.edge * 100
                OddsStat(label: "你的优势", value: String(format: "%+.0f 点", e), tint: e >= 0 ? Theme.up : Theme.down)
            }
            if editable {
                Text("拖动圆点，写下你自己的把握。")
                    .font(.system(size: 11)).foregroundStyle(Theme.ink3)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.bg))
    }
}

struct OddsStat: View {
    let label: String
    let value: String
    let tint: Color
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.ink3)
            Text(value).font(.system(size: 20, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
                .contentTransition(.numericText())
            if let sub { Text(sub).font(.system(size: 10)).foregroundStyle(Theme.ink3) }
        }
    }
}

extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(Swift.max(self, lo), hi) }
}
