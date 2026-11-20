import SwiftUI

// MARK: - All theses

struct ThesesListView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("我的观点").font(.serif(32, .semibold)).padding(.leading, 4)
                TrackRecordCard()
                SectionLabel(text: "进行中").padding(.leading, 4)
                ForEach(store.theses) { t in
                    Button { store.path.append(Route.thesis(t.id)) } label: {
                        ThesisRow(thesis: t)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(16)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThesisRow: View {
    let thesis: Thesis
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(thesis.ticker).font(.system(size: 16, weight: .bold))
                Text(thesis.company).font(.system(size: 13)).foregroundStyle(Theme.ink3)
                Spacer()
                StatusBadge(status: thesis.status)
            }
            Text(thesis.claim).font(.serif(16)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
            StopMeter(thesis: thesis)
        }
        .padding(16)
        .card(20)
    }
}

/// Calibration — the long-run reason to keep using Bobby, and the seed of copy-trading credibility.
struct TrackRecordCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("你的战绩").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("模拟盘 · 近 90 天").font(.system(size: 12)).foregroundStyle(Theme.ink3)
            }
            HStack(alignment: .bottom, spacing: 0) {
                RecordStat(value: "7 / 11", label: "观点判断正确")
                Spacer()
                RecordStat(value: "+4.8%", label: "跑赢标普 500", tint: Theme.up)
                Spacer()
                RecordStat(value: "良好", label: "校准度", tint: Theme.violet)
            }
            CalibrationStrip()
            Text("你说有 60–70% 把握时，6 次对了 4 次。财报后延续行情是你最擅长的场景。")
                .font(.system(size: 13)).foregroundStyle(Theme.ink2)
        }
        .padding(18)
        .card(22)
    }
}

struct RecordStat: View {
    let value: String
    let label: String
    var tint: Color = Theme.ink
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.ink3)
        }
    }
}

struct CalibrationStrip: View {
    // stated confidence bucket -> hit rate
    let buckets: [(String, Double, Double)] = [("50%", 0.55, 0.50), ("60%", 0.65, 0.67), ("70%", 0.75, 0.60), ("80%", 0.85, 0.50)]
    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ForEach(buckets, id: \.0) { b in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.05)).frame(height: 56)
                        RoundedRectangle(cornerRadius: 5).fill(Theme.brand).frame(height: 56 * b.2)
                        Rectangle().fill(Theme.ink).frame(height: 1.5).offset(y: -56 * b.1)
                    }
                    Text(b.0).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.ink3)
                }
            }
        }
    }
}

// MARK: - Thesis detail

struct ThesisDetailView: View {
    @Environment(AppStore.self) private var store
    @Bindable var thesis: Thesis

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StatusBadge(status: thesis.status)
                        Spacer()
                        if thesis.trackedDaysAgo > 0 {
                            Text("已跟踪 \(thesis.trackedDaysAgo) 天").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                        }
                    }
                    Text(thesis.claim).font(.serif(24, .medium)).lineSpacing(3)
                }

                if thesis.status == .watch {
                    DecisionCard(thesis: thesis)
                }
                if thesis.status == .reviewDue {
                    Button { store.path.append(Route.review(thesis.id)) } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("复盘已生成").font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.brand))
                    }
                    .buttonStyle(PressStyle())
                }

                PriceChartCard(thesis: thesis)

                if let p = thesis.position {
                    PositionCard(thesis: thesis, position: p)
                }

                VStack(alignment: .leading, spacing: 12) {
                    BlockTitle(icon: "scope", title: "正在盯的线", trailing: "实时")
                    ForEach(thesis.conditions) { c in ConditionRow(condition: c, price: thesis.price) }
                    Divider().opacity(0.5)
                    BlockTitle(icon: "calendar.badge.checkmark", title: "检查点", trailing: thesis.checkpoints.first?.date, tint: Theme.violet)
                    ForEach(thesis.checkpoints) { cp in
                        HStack {
                            Text(cp.metric).font(.system(size: 14))
                            Spacer()
                            if let a = cp.actual {
                                Image(systemName: cp.hit == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(cp.hit == true ? Theme.up : Theme.down)
                                Text(a).font(.system(size: 13, weight: .semibold).monospacedDigit())
                            } else {
                                Text(cp.expectation).font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(Theme.ink2)
                            }
                        }
                    }
                }
                .padding(16)
                .card(20)

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "动态")
                    if thesis.events.isEmpty {
                        Text("暂无动态。").font(.system(size: 14)).foregroundStyle(Theme.ink3)
                    }
                    ForEach(thesis.events) { e in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: e.icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(e.tint)
                                .frame(width: 28, height: 28).background(Circle().fill(e.tint.opacity(0.1)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.when).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.ink3)
                                Text(e.text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(16)
                .card(20)

                DemoControls(thesis: thesis)
                Color.clear.frame(height: 20)
            }
            .padding(16)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(thesis.ticker)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DecisionCard: View {
    @Environment(AppStore.self) private var store
    @Bindable var thesis: Thesis
    @State private var decided: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.amber)
                Text("股价正在测试你的失效线").font(.system(size: 15, weight: .semibold))
            }
            Text("你说过收盘跌破 \(thesis.stop.usd) 就说明判断错了。现在还没收破，趁现在做决定，别等到收盘前一分钟。")
                .font(.system(size: 14)).foregroundStyle(Theme.ink2)
            if let d = decided {
                Label(d, systemImage: "checkmark.circle.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.up)
            } else {
                HStack(spacing: 8) {
                    ForEach(["按计划持有", "现在离场", "改写观点"], id: \.self) { o in
                        Button {
                            withAnimation { decided = o == "按计划持有" ? "继续持有，收盘自动离场仍然生效。" : o == "现在离场" ? "模拟持仓已平仓。" : "已打开编辑。" }
                        } label: {
                            Text(o).font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(o == "按计划持有" ? .white : Theme.ink)
                                .frame(maxWidth: .infinity).frame(height: 40)
                                .background(Capsule().fill(o == "按计划持有" ? Theme.ink : Color.black.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.amber.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.amber.opacity(0.3), lineWidth: 1))
        .task {
            guard store.tour else { return }
            try? await Task.sleep(for: .seconds(4.5))
            withAnimation { decided = "继续持有，收盘自动离场仍然生效。" }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

struct PositionCard: View {
    let thesis: Thesis
    let position: PaperPosition
    var body: some View {
        let pnl = (thesis.price - position.avgPrice) * Double(position.shares)
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("模拟持仓").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                Text("\(position.shares) 股 @ \(position.avgPrice.usd)").font(.system(size: 15, weight: .semibold).monospacedDigit())
                Text("已成交 \(position.filledLegs)/\(thesis.plan.count) 档").font(.system(size: 12)).foregroundStyle(Theme.ink2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("浮动盈亏").font(.system(size: 12)).foregroundStyle(Theme.ink3)
                Text((pnl >= 0 ? "+" : "−") + abs(pnl).usd0)
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(pnl >= 0 ? Theme.up : Theme.down)
                    .contentTransition(.numericText())
            }
        }
        .padding(16)
        .card(20)
    }
}

/// Prototype-only: compress weeks of market time into a tap.
struct DemoControls: View {
    @Environment(AppStore.self) private var store
    let thesis: Thesis
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("原型演示控制", systemImage: "forward.fill")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink3)
            HStack(spacing: 8) {
                DemoButton(title: "价格跌到失效线") { store.simulateDip(thesis) }
                DemoButton(title: "快进到 2 月 16 日") { store.simulateEarnings(thesis) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(Theme.ink3.opacity(0.5)))
    }
}

struct DemoButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity).frame(height: 38)
                .background(Capsule().fill(Color.black.opacity(0.04)))
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Review

struct ReviewView: View {
    @Environment(AppStore.self) private var store
    @Bindable var thesis: Thesis
    @State private var shared = false

    var hits: Int { thesis.checkpoints.filter { $0.hit == true }.count }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("复盘 · \(thesis.ticker) · Q2 FY27").font(.system(size: 11, weight: .bold)).tracking(1.3).foregroundStyle(Theme.brand)
                    Text("大体判断对了，但原因和你想的不完全一样。").font(.serif(28, .medium)).lineSpacing(3)
                    Text("写下观点以来股价 \(String(format: "%+.1f%%", (thesis.price / 373.27 - 1) * 100)) 。ARR 判断撑住了，内生增长没有。")
                        .font(.system(size: 15)).foregroundStyle(Theme.ink2)
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("检查点").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.ink3)
                        Spacer()
                        Text("你的预期").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.ink3).frame(width: 74, alignment: .trailing)
                        Text("实际").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.ink3).frame(width: 96, alignment: .trailing)
                    }
                    .padding(.bottom, 8)
                    ForEach(thesis.checkpoints) { cp in
                        Divider()
                        HStack {
                            Image(systemName: cp.hit == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(cp.hit == true ? Theme.up : Theme.down)
                            Text(cp.metric).font(.system(size: 14))
                            Spacer()
                            Text(cp.expectation).font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.ink2).frame(width: 74, alignment: .trailing)
                            Text(cp.actual ?? "—").font(.system(size: 13, weight: .semibold).monospacedDigit()).frame(width: 96, alignment: .trailing)
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(16)
                .card(20)

                HStack(spacing: 12) {
                    ReviewStat(value: "\(hits)/\(thesis.checkpoints.count)", label: "检查点命中")
                    ReviewStat(value: thesis.myProbability.pct, label: "你的把握")
                    ReviewStat(value: (thesis.unrealized ?? 0) >= 0 ? "+" + (thesis.unrealized ?? 0).usd0 : "−" + abs(thesis.unrealized ?? 0).usd0, label: "模拟盈亏", tint: (thesis.unrealized ?? 0) >= 0 ? Theme.up : Theme.down)
                }

                VStack(alignment: .leading, spacing: 10) {
                    BlockTitle(icon: "lightbulb", title: "这次可以带走的经验", trailing: nil, tint: Theme.amber)
                    Text("• 市场买单的是 AI 安全 ARR，不是内生增长。下次产品指标的权重要高于表面增速。")
                    Text("• 你比市场乐观 13 个点，并且判断对了。你 60–70% 把握的判断现在 7 次对 5 次。")
                    Text("• 第 2 档一直没成交，缺口守住了。下次底仓可以给大一点。")
                }
                .font(.system(size: 14)).foregroundStyle(Theme.ink.opacity(0.85))
                .padding(16)
                .card(20)

                ShareCardPreview(thesis: thesis, hits: hits)

                VStack(spacing: 10) {
                    PrimaryButton(title: shared ? "已分享到社区" : "分享到社区", icon: shared ? "checkmark" : "person.2") {
                        withAnimation { shared = true }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    SecondaryButton(title: "延续到 Q3", icon: "arrow.trianglehead.clockwise") {}
                }
                Color.clear.frame(height: 20).id("end")
            }
            .padding(16)
        }
        .task {
            guard store.tour else { return }
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 2.4)) { proxy.scrollTo("end", anchor: .bottom) }
            try? await Task.sleep(for: .seconds(3.4))
            withAnimation { shared = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("复盘")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if thesis.status == .reviewDue { thesis.status = .closed } }
    }
}

struct ReviewStat: View {
    let value: String
    let label: String
    var tint: Color = Theme.ink
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 20, weight: .semibold).monospacedDigit()).foregroundStyle(tint)
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card(18)
    }
}

/// What other users see — a verified call, which is what makes copy-trading credible.
struct ShareCardPreview: View {
    let thesis: Thesis
    let hits: Int
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            NebulaBackground(seed: 3)
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    BobbyMark(size: 22)
                    Text("已验证的判断").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("11 月 19 日写下 · 2 月 16 日复盘").font(.system(size: 11)).opacity(0.7)
                }
                Spacer()
                Text(thesis.claim).font(.serif(18)).lineSpacing(2)
                HStack(spacing: 8) {
                    TickerPill(ticker: thesis.ticker, change: (thesis.price / 373.27 - 1) * 100, dark: true)
                    Text("\(hits)/\(thesis.checkpoints.count) 检查点命中 · 当时把握 \(thesis.myProbability.pct)")
                        .font(.system(size: 12, weight: .medium)).opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
