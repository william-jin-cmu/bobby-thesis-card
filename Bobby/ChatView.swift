import SwiftUI
import Charts

struct ChatView: View {
    @Environment(AppStore.self) private var store
    let trade: HotTrade

    @State private var stepsDone = 0
    @State private var showAnswer = false
    @State private var showThesis = false
    @State private var expanded = false
    @State private var askProfile = false
    @State private var showOrder = false
    @State private var pendingAction: PendingAction? = nil

    enum PendingAction { case track, trade }

    private let steps = ["风险评估", "资讯检索", "行情查询", "研报查询", "基本面查询", "图表生成", "预测市场"]

    var thesis: Thesis { store.panwDraft }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        userBubble
                        ThinkingView(steps: steps, done: stepsDone, finished: showAnswer)
                        if showAnswer {
                            answer.transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        if showThesis {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("我把这份分析整理成了一张可以跟踪的观点卡。")
                                    .font(.system(size: 15, weight: .medium))
                                ThesisCardView(
                                    thesis: thesis,
                                    isTracked: store.theses.contains { $0.id == thesis.id },
                                    onTrack: { request(.track) },
                                    onTrade: { request(.trade) },
                                    onOpen: { store.path.append(Route.thesis(thesis.id)) }
                                )
                            }
                            .id("thesis")
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        }
                        Color.clear.frame(height: 130)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
                .onChange(of: showThesis) { _, v in
                    if v { withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo("thesis", anchor: .top) } }
                }
            }
            Composer(placeholder: "继续追问…")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) { BobbyMark(size: 20); Text("Bobby AI").font(.system(size: 17, weight: .semibold)) }
            }
        }
        .task { await run() }
        .sheet(isPresented: $askProfile) {
            ProfileSheet(auto: store.tour) { profile in
                store.profile = profile
                askProfile = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    continueAction()
                }
            }
            .presentationDetents([.height(560)])
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showOrder) {
            PaperOrderSheet(thesis: thesis, profile: store.profile!, cash: store.accountCash, auto: store.tour) { shares in
                store.placePaperOrder(thesis, shares: shares, legs: thesis.plan.count)
            }
            .presentationDetents([.large])
            .presentationCornerRadius(32)
        }
    }

    private func request(_ a: PendingAction) {
        pendingAction = a
        if store.profile == nil { askProfile = true } else { continueAction() }
    }

    private func continueAction() {
        switch pendingAction {
        case .track:
            store.track(thesis)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .trade:
            showOrder = true
        case nil: break
        }
        pendingAction = nil
    }

    private func run() async {
        guard !showAnswer else { return }
        for i in 1...steps.count {
            try? await Task.sleep(for: .milliseconds(420))
            withAnimation(.easeOut(duration: 0.25)) { stepsDone = i }
        }
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.spring(duration: 0.5)) { showAnswer = true }
        try? await Task.sleep(for: .milliseconds(900))
        withAnimation(.spring(duration: 0.6)) { showThesis = true }
        if store.tour && store.demoSheet == nil && !store.theses.contains(where: { $0.id == thesis.id }) {
            try? await Task.sleep(for: .seconds(1.6))
            for v in [0.67, 0.69, 0.71, 0.72, 0.71, 0.70] {
                withAnimation(.spring(duration: 0.25)) { thesis.myProbability = v }
                try? await Task.sleep(for: .milliseconds(140))
            }
        }
        if let d = store.demoSheet {
            store.demoSheet = nil
            try? await Task.sleep(for: .milliseconds(900))
            if d == "profile" { pendingAction = .track; askProfile = true }
            if d == "order" { showOrder = true }
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 50)
            Text("帮我全面解读这个交易热点：\(trade.headline)")
                .font(.system(size: 15))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.06)))
        }
    }

    // Condensed answer: the verdict first, the full report on demand.
    private var answer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("业绩兑现、AI 安全叙事、空头回补，三件事同时发生的一根跳空。")
                .font(.serif(21, .medium))
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 10) {
                KeyRow(icon: "arrow.up.right", tint: Theme.up, title: "多方", text: "FY27 营收指引上调到 145.2–145.7 亿美元（预期 141.6 亿）。AI 安全 ARR 五个季度从 0 到 1.7 亿。")
                KeyRow(icon: "arrow.down.right", tint: Theme.down, title: "空方", text: "增长靠并购；45 亿全股票收购摊薄股本。87 倍前瞻市盈率容错很小。")
                KeyRow(icon: "scope", tint: Theme.violet, title: "胜负手", text: "2 月 16 日的 Q2 财报：AIRS 净增 ARR、内生增长、毛利率。")
            }
            .padding(16)
            .card(20)

            PriceChartCard(thesis: thesis, compact: true)

            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 12) {
                    ReportSection(n: "1", title: "财报本身", text: "营收和 EPS 双超预期，NGS ARR 加速。管理层年内第二次上调全年指引。")
                    ReportSection(n: "2", title: "45 亿美元买 Applied Compute", text: "押注开源权重模型的训练与推理安全，是战略性下注，但全股票支付有摊薄，标的收入也未披露。")
                    ReportSection(n: "3", title: "「AI 编码安全盲区」是叙事", text: "对安全预算的故事有用，但它不是收入。真正的证据是 ARR、平台化和部署数。")
                    ReportSection(n: "4", title: "位置与估值", text: "盘前 373 美元，较 11-17 收盘涨 20.6%，距 52 周高点还差 13.7%。RSI 47.8；50 日线 366.70 美元是第一道检验。")
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 11))
                        Text("公司公告 · WSJ · BankInfoSecurity · FMP，2026-11-17 至 11-19")
                    }
                    .font(.system(size: 12)).foregroundStyle(Theme.ink3)
                }
                .padding(.top, 10)
            } label: {
                Text(expanded ? "收起完整分析" : "展开完整分析（6 节）")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink2)
            }
            .tint(Theme.ink2)
        }
    }
}

struct KeyRow: View {
    let icon: String
    let tint: Color
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
                .frame(width: 26, height: 26).background(Circle().fill(tint.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 14)).foregroundStyle(Theme.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ReportSection: View {
    let n: String
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(n). \(title)").font(.system(size: 15, weight: .semibold))
            Text(text).font(.system(size: 14)).foregroundStyle(Theme.ink.opacity(0.8))
        }
    }
}

struct ThinkingView: View {
    let steps: [String]
    let done: Int
    let finished: Bool
    @State private var open = true
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation { open.toggle() } } label: {
                HStack(spacing: 8) {
                    BobbyMark(size: 18)
                    Text(finished ? "思考了 58 秒 · \(steps.count) 步" : "正在思考 · 第 \(min(done + 1, steps.count))/\(steps.count) 步")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(finished ? Theme.ink2 : Theme.ink)
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.ink3)
                }
            }
            .buttonStyle(.plain)
            if open && !finished {
                FlowChips(steps: steps, done: done)
                    .transition(.opacity)
            }
        }
        .onChange(of: finished) { _, f in if f { withAnimation { open = false } } }
    }
}

struct FlowChips: View {
    let steps: [String]
    let done: Int
    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 110), spacing: 8)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 6) {
                    if i < done {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.up)
                    } else if i == done {
                        ProgressView().controlSize(.mini)
                    } else {
                        Circle().stroke(Theme.ink3, lineWidth: 1).frame(width: 8, height: 8)
                    }
                    Text(s).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(i <= done ? Theme.ink : Theme.ink3)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Capsule().fill(Color.black.opacity(i <= done ? 0.05 : 0.025)))
            }
        }
    }
}

// MARK: - Price chart with the thesis levels drawn on it

struct PriceChartCard: View {
    let thesis: Thesis
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(thesis.ticker).font(.system(size: 15, weight: .bold))
                Text(thesis.price.usd).font(.system(size: 15, weight: .semibold).monospacedDigit())
                Text(String(format: "%+.2f%%", thesis.change))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(thesis.change >= 0 ? Theme.up : Theme.down)
                Spacer()
                Text("3M").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink3)
            }
            Chart {
                ForEach(thesis.series) { p in
                    AreaMark(x: .value("Day", p.day), yStart: .value("Base", yMin), yEnd: .value("Price", p.price))
                        .foregroundStyle(LinearGradient(colors: [Theme.violet.opacity(0.18), Theme.violet.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", p.day), y: .value("Price", p.price))
                        .foregroundStyle(Theme.violet)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                RuleMark(y: .value("Stop", thesis.stop))
                    .foregroundStyle(Theme.down.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .bottom, alignment: .leading) {
                        Text("失效线 \(thesis.stop.usd)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.down)
                    }
                RuleMark(y: .value("Target", thesis.target))
                    .foregroundStyle(Theme.up.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("卖方目标价 \(thesis.target.usd0)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.up)
                    }
                if let last = thesis.series.last {
                    PointMark(x: .value("Day", last.day), y: .value("Price", last.price))
                        .foregroundStyle(Theme.violet)
                        .symbolSize(60)
                }
            }
            .chartYScale(domain: yMin...yMax)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Theme.hairline)
                    AxisValueLabel().font(.system(size: 10)).foregroundStyle(Theme.ink3)
                }
            }
            .frame(height: compact ? 150 : 200)
        }
        .padding(16)
        .card(20)
    }

    private var yMin: Double { (thesis.series.map(\.price).min() ?? 0) * 0.94 }
    private var yMax: Double { max(thesis.series.map(\.price).max() ?? 1, thesis.target) * 1.04 }
}
