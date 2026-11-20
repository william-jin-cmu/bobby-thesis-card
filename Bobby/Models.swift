import SwiftUI
import Observation

// MARK: - Thesis domain

enum ThesisStatus: String {
    case draft, onTrack, watch, invalidated, reviewDue, closed

    var label: String {
        switch self {
        case .draft: "草稿"
        case .onTrack: "按计划"
        case .watch: "接近触发"
        case .invalidated: "已证伪"
        case .reviewDue: "待复盘"
        case .closed: "已复盘"
        }
    }
    var color: Color {
        switch self {
        case .draft: Theme.ink3
        case .onTrack: Theme.up
        case .watch: Theme.amber
        case .invalidated: Theme.down
        case .reviewDue: Theme.violet
        case .closed: Theme.ink2
        }
    }
}

struct PlanLeg: Identifiable {
    let id = UUID()
    var price: Double
    var weight: Double      // share of planned position
    var note: String
}

struct Condition: Identifiable {
    let id = UUID()
    var text: String
    var level: Double?      // price level if price-based
    var kind: Kind
    enum Kind { case invalidation, confirmation }
}

struct Checkpoint: Identifiable {
    let id = UUID()
    var date: String
    var metric: String
    var expectation: String
    var actual: String? = nil
    var hit: Bool? = nil
}

struct ThesisEvent: Identifiable {
    let id = UUID()
    var when: String
    var text: String
    var icon: String
    var tint: Color = Theme.ink2
}

struct PaperPosition {
    var shares: Int
    var avgPrice: Double
    var filledLegs: Int
}

struct PricePoint: Identifiable {
    let id = UUID()
    var day: Int
    var price: Double
}

@Observable
final class Thesis: Identifiable {
    let id = UUID()
    var ticker: String
    var company: String
    var claim: String
    var reasons: [String]
    var myProbability: Double
    var marketProbability: Double
    var marketQuestion: String
    var marketSource: String
    var price: Double
    var change: Double
    var target: Double
    var plan: [PlanLeg]
    var stop: Double
    var conditions: [Condition]
    var checkpoints: [Checkpoint]
    var status: ThesisStatus
    var events: [ThesisEvent]
    var series: [PricePoint]
    var position: PaperPosition?
    var trackedDaysAgo: Int

    init(ticker: String, company: String, claim: String, reasons: [String], myProbability: Double, marketProbability: Double, marketQuestion: String, marketSource: String, price: Double, change: Double, target: Double, plan: [PlanLeg], stop: Double, conditions: [Condition], checkpoints: [Checkpoint], status: ThesisStatus, events: [ThesisEvent], series: [PricePoint], position: PaperPosition? = nil, trackedDaysAgo: Int = 0) {
        self.ticker = ticker; self.company = company; self.claim = claim; self.reasons = reasons
        self.myProbability = myProbability; self.marketProbability = marketProbability
        self.marketQuestion = marketQuestion; self.marketSource = marketSource
        self.price = price; self.change = change; self.target = target; self.plan = plan; self.stop = stop
        self.conditions = conditions; self.checkpoints = checkpoints; self.status = status
        self.events = events; self.series = series; self.position = position; self.trackedDaysAgo = trackedDaysAgo
    }

    var edge: Double { myProbability - marketProbability }
    var distanceToStop: Double { (price - stop) / price }
    var nextCheckpoint: Checkpoint? { checkpoints.first { $0.actual == nil } }
    var unrealized: Double? {
        guard let p = position else { return nil }
        return (price - p.avgPrice) * Double(p.shares)
    }
}

// MARK: - Investor profile (asked once, on first "Track")

struct InvestorProfile {
    var risk: String
    var horizon: String
    var maxPosition: Double   // fraction of account per idea
}

// MARK: - Home content

struct HotTrade: Identifiable {
    let id = UUID()
    let tag: String
    let minutesAgo: Int
    let headline: String
    let ticker: String
    let change: Double
    let seed: Double
}

struct Banner: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let icon: String
    let tint: Color
    let route: Route?
    static func == (a: Banner, b: Banner) -> Bool { a.id == b.id }
}

enum Route: Hashable {
    case chat(UUID)        // hot trade id
    case thesis(UUID)
    case review(UUID)
    case theses
}

// MARK: - Store

@Observable
final class AppStore {
    var path = NavigationPath()
    var profile: InvestorProfile? = nil
    var banner: Banner? = nil
    let accountCash: Double = 1_000_000

    var hotTrades: [HotTrade] = [
        HotTrade(tag: "财报", minutesAgo: 17, headline: "Palo Alto CEO：企业尚未搞清 AI 编码安全", ticker: "PANW", change: 9.15, seed: 0),
        HotTrade(tag: "宏观", minutesAgo: 42, headline: "就业数据走软，沃勒提出 12 月降息 50 个基点", ticker: "TLT", change: 1.84, seed: 2),
        HotTrade(tag: "半导体", minutesAgo: 66, headline: "英伟达接洽 Arm CEO 探讨接任可能", ticker: "NVDA", change: -2.31, seed: 4)
    ]

    var theses: [Thesis] = [Thesis.mu]
    /// The thesis Bobby drafts at the end of the PANW analysis.
    let panwDraft: Thesis = Thesis.panw

    /// Prototype screenshot states: `-demo <state>` launch argument.
    var demoSheet: String? = nil
    /// `-tour`: each demo state plays its own interactions for screen recording.
    var tour = ProcessInfo.processInfo.arguments.contains("-tour")
    func boot(_ state: String) {
        let panw = panwDraft
        let profile = InvestorProfile(risk: "按计划来", horizon: "几个月", maxPosition: 0.05)
        switch state {
        case "chat": path.append(Route.chat(hotTrades[0].id))
        case "profile": path.append(Route.chat(hotTrades[0].id)); demoSheet = "profile"
        case "order": profile_(profile); path.append(Route.chat(hotTrades[0].id)); demoSheet = "order"
        case "tracked": profile_(profile); track(panw); path.append(Route.chat(hotTrades[0].id))
        case "theses": profile_(profile); placePaperOrder(panw, shares: 53, legs: 3); path.append(Route.theses)
        case "watch":
            profile_(profile); placePaperOrder(panw, shares: 53, legs: 3)
            path.append(Route.thesis(panw.id))
            if tour { later(1.6) { self.simulateDip(panw) } } else { simulateDip(panw) }
        case "banner":
            profile_(profile); placePaperOrder(panw, shares: 53, legs: 3)
            if tour { later(1.4) { self.simulateEarnings(panw) } } else { simulateEarnings(panw) }
        case "detail":
            profile_(profile); placePaperOrder(panw, shares: 53, legs: 3); simulateEarnings(panw)
            path.append(Route.thesis(panw.id)); banner = nil
        case "review":
            profile_(profile); placePaperOrder(panw, shares: 53, legs: 3); simulateEarnings(panw)
            path.append(Route.review(panw.id)); banner = nil
        default: break
        }
    }
    private func profile_(_ p: InvestorProfile) { profile = p }
    func later(_ s: Double, _ f: @escaping () -> Void) {
        Task { @MainActor in try? await Task.sleep(for: .seconds(s)); f() }
    }

    func hotTrade(_ id: UUID) -> HotTrade? { hotTrades.first { $0.id == id } }
    func thesis(_ id: UUID) -> Thesis? { ([panwDraft] + theses).first { $0.id == id } }

    func track(_ t: Thesis) {
        guard !theses.contains(where: { $0.id == t.id }) else { return }
        t.status = .onTrack
        t.events.insert(ThesisEvent(when: "刚刚", text: "你开始跟踪这个观点。Bobby 会盯住 3 个条件和 1 个检查日。", icon: "scope", tint: Theme.violet), at: 0)
        withAnimation(.spring) { theses.insert(t, at: 0) }
    }

    func placePaperOrder(_ t: Thesis, shares: Int, legs: Int) {
        let filledLeg = t.plan.first!
        t.position = PaperPosition(shares: shares, avgPrice: min(t.price, filledLeg.price), filledLegs: 1)
        t.events.insert(ThesisEvent(when: "刚刚", text: "模拟单成交：\(shares) 股 @ \(t.price.usd)（第 1/\(legs) 档）。第 2、3 档挂限价单等待。", icon: "checkmark.seal.fill", tint: Theme.up), at: 0)
        if !theses.contains(where: { $0.id == t.id }) { track(t) }
    }

    func show(_ b: Banner) {
        withAnimation(.spring(duration: 0.45)) { banner = b }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(tour ? 30 : 6))
            if banner?.id == b.id { withAnimation(.easeInOut) { banner = nil } }
        }
    }

    // Demo controls: compress weeks into a tap.
    func simulateDip(_ t: Thesis) {
        t.price = t.stop * 1.004
        t.change = -3.42
        t.series.append(PricePoint(day: (t.series.last?.day ?? 0) + 1, price: t.price))
        t.status = .watch
        t.events.insert(ThesisEvent(when: "12 月 3 日 10:41", text: "股价 \(t.price.usd)，距你的失效线（50 日线 \(t.stop.usd)）只剩 0.4%。第 2 档限价单还差 1.2%。", icon: "exclamationmark.triangle.fill", tint: Theme.amber), at: 0)
        show(Banner(title: "\(t.ticker) 正在测试你的失效线", body: "距离你设的 50 日线失效线只差 0.4%。持有、加仓还是离场？", icon: "exclamationmark.triangle.fill", tint: Theme.amber, route: .thesis(t.id)))
    }

    func simulateEarnings(_ t: Thesis) {
        t.price = 402.80
        t.change = 6.18
        t.series.append(contentsOf: [
            PricePoint(day: (t.series.last?.day ?? 0) + 1, price: 381),
            PricePoint(day: (t.series.last?.day ?? 0) + 2, price: 402.8)
        ])
        if t.checkpoints.indices.contains(0) {
            t.checkpoints[0].actual = "净增 4100 万美元"; t.checkpoints[0].hit = true
        }
        if t.checkpoints.indices.contains(1) {
            t.checkpoints[1].actual = "内生 13.8%"; t.checkpoints[1].hit = false
        }
        if t.checkpoints.indices.contains(2) {
            t.checkpoints[2].actual = "毛利率 68.4%"; t.checkpoints[2].hit = true
        }
        t.status = .reviewDue
        t.events.insert(ThesisEvent(when: "2 月 16 日 16:20", text: "Q2 财报已发布，3 个检查点命中 2 个，复盘已生成。", icon: "doc.text.magnifyingglass", tint: Theme.violet), at: 0)
        show(Banner(title: "检查日到了：\(t.ticker) Q2 财报", body: "3 个检查点命中 2 个。Bobby 已写好复盘，1 分钟读完。", icon: "doc.text.magnifyingglass", tint: Theme.violet, route: .review(t.id)))
    }
}

// MARK: - Seed data (demo values, not live market data)

extension Thesis {
    static var panw: Thesis {
        Thesis(
            ticker: "PANW", company: "派拓网络",
            claim: "财报跳空守得住：AI 安全的 ARR 是真金白银，不只是叙事。",
            reasons: [
                "FY27 营收指引上调到 145.2–145.7 亿美元，高于 141.6 亿的一致预期",
                "AI 安全 ARR 五个季度从 0 做到 1.7 亿美元",
                "一根跳空同时收复 20/50/200 日线"
            ],
            myProbability: 0.65, marketProbability: 0.52,
            marketQuestion: "2027 年 2 月 20 日 PANW 收在 400 美元上方",
            marketSource: "期权隐含 · Kalshi",
            price: 373.27, change: 9.22, target: 415,
            plan: [
                PlanLeg(price: 373, weight: 0.4, note: "确认后先建底仓"),
                PlanLeg(price: 362, weight: 0.3, note: "回踩缺口加仓"),
                PlanLeg(price: 352, weight: 0.3, note: "20 日线附近补齐")
            ],
            stop: 366.70,
            conditions: [
                Condition(text: "日线收盘跌破 50 日线", level: 366.70, kind: .invalidation),
                Condition(text: "Q2 AI 安全 ARR 净增 < 3000 万美元", level: nil, kind: .invalidation),
                Condition(text: "放量收在 400 美元上方", level: 400, kind: .confirmation)
            ],
            checkpoints: [
                Checkpoint(date: "2027-02-16", metric: "Prisma AIRS 净增 ARR", expectation: "3000–4000 万美元"),
                Checkpoint(date: "2027-02-16", metric: "剔除并购的内生增长", expectation: "≥ 15%"),
                Checkpoint(date: "2027-02-16", metric: "毛利率", expectation: "守住 68%")
            ],
            status: .draft,
            events: [],
            series: Thesis.makeSeries(start: 330, points: [345, 338, 352, 368, 391, 410, 425, 418, 401, 389, 372, 360, 341, 335, 342, 373.27])
        )
    }

    static var mu: Thesis {
        Thesis(
            ticker: "MU", company: "美光科技",
            claim: "9 倍市盈率被错杀：HBM 长约让这轮周期比市场以为的更长。",
            reasons: [
                "26 份战略客户协议，约 1500 亿美元 RPO 覆盖到 2030 年",
                "FY27 出货已有 75% 锁定",
                "回撤 41% 后落在 200 日线附近"
            ],
            myProbability: 0.60, marketProbability: 0.47,
            marketQuestion: "2026 年 12 月 31 日 MU 高于 850 美元",
            marketSource: "Polymarket",
            price: 731.96, change: 1.12, target: 1050,
            plan: [
                PlanLeg(price: 740, weight: 0.4, note: "底仓"),
                PlanLeg(price: 705, weight: 0.3, note: "近期低点加仓"),
                PlanLeg(price: 670, weight: 0.3, note: "最后一档")
            ],
            stop: 666,
            conditions: [
                Condition(text: "收盘跌破 666–705 美元低点区", level: 666, kind: .invalidation),
                Condition(text: "站回 200 日线（770 美元）并守住一周", level: 770, kind: .confirmation)
            ],
            checkpoints: [
                Checkpoint(date: "2026-12-23", metric: "FY27 Q1 营收", expectation: "≥ 617 亿美元")
            ],
            status: .onTrack,
            events: [
                ThesisEvent(when: "11 月 19 日 09:30", text: "模拟单成交：540 股 @ $738.40（第 1/3 档）。", icon: "checkmark.seal.fill", tint: Theme.up),
                ThesisEvent(when: "11 月 12 日", text: "你从「帮我挑一只值得买的股票」开始跟踪这个观点。", icon: "scope", tint: Theme.violet)
            ],
            series: Thesis.makeSeries(start: 640, points: [700, 760, 840, 920, 1010, 1120, 1255, 1180, 1050, 930, 860, 790, 760, 742, 731.96]),
            position: PaperPosition(shares: 540, avgPrice: 738.40, filledLegs: 1),
            trackedDaysAgo: 7
        )
    }

    static func makeSeries(start: Double, points: [Double]) -> [PricePoint] {
        var out: [PricePoint] = []
        var day = 0
        var prev = start
        for p in points {
            for i in 0..<4 {
                let f = Double(i) / 4
                let wobble = sin(Double(day) * 1.7) * prev * 0.008
                out.append(PricePoint(day: day, price: prev + (p - prev) * f + wobble))
                day += 1
            }
            prev = p
        }
        out.append(PricePoint(day: day, price: points.last ?? start))
        return out
    }
}
