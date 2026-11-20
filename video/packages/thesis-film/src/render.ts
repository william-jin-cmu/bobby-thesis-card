import { sealVisualTrack } from "@hypit/composition";
import type { VisualElement } from "@hypit/composition";
import { htmlVisual } from "@hypit/html-program";
import type { FontStackRef, SynchronizedMedia } from "@hypit/media";
import type { Timeline } from "@hypit/timeline";
import type { SpatialFrame } from "@hypit/spatial";
import { assertTemporalWindowFor } from "@hypit/temporal";
import type { TemporalWindow } from "@hypit/temporal";

export const CLIP_KEYS = ["home", "chat", "profile", "order", "watch", "banner", "review", "theses"] as const;
export type ClipKey = typeof CLIP_KEYS[number];
export type FilmOptions = { id: string; z: number };
export type Fonts = { serif: FontStackRef; sans: FontStackRef; sansm: FontStackRef };

/** A source interval [from, to) shown over `dur` output frames; from === to holds that frame. */
type Seg = { from: number; to: number; dur: number };
/** Camera key: scale `s` around screen point (fx, fy) (0..1 of the recording), landing at canvas y `ty`. */
type Cam = { at: number; s: number; fx?: number; fy?: number; ty?: number };
/** Caption: chunks split by "|", "{...}" is highlighted, "\n" breaks the line. */
type Cap = { at: number; until?: number; text: string };
type Ring = { at: number; x0: number; y0: number; x1: number; y1: number; label: string };
type Beat = { key: ClipKey; trans: "rise" | "push" | "fade"; step: number; lead?: number; segs: Seg[];
  cams: Cam[]; caps: Cap[]; ring?: Ring };

const FPS = 30;
const HOOK = 140;
const OUTRO = 132;
const TAIL = 20;

/* The storyboard. Source frame numbers refer to the 30 fps copies in assets/clips. */
const BEATS: Beat[] = [
  { key: "home", trans: "rise", step: -1, lead: 26, segs: [{ from: 132, to: 252, dur: 120 }],
    cams: [{ at: 0, s: 1 }, { at: 120, s: 1.05, fx: .5, fy: .42 }],
    caps: [{ at: 4, text: "Bobby 每天|把热点|变成{交易线索}" }] },
  { key: "chat", trans: "push", step: 0, segs: [
      { from: 92, to: 186, dur: 34 }, { from: 186, to: 222, dur: 36 }, { from: 222, to: 244, dur: 22 },
      { from: 244, to: 300, dur: 56 }, { from: 300, to: 300, dur: 18 }],
    cams: [{ at: 0, s: 1 }, { at: 70, s: 1 }, { at: 86, s: 1.55, fx: .5, fy: .43, ty: 1150 }],
    caps: [{ at: 4, until: 66, text: "一键分析，|{结论先行}" }, { at: 64, text: "自动整理成|一张{观点卡}" }],
    ring: { at: 90, x0: .07, y0: .418, x1: .93, y1: .512, label: "你的把握 vs 市场隐含概率" } },
  { key: "profile", trans: "fade", step: 1, segs: [
      { from: 236, to: 256, dur: 20 }, { from: 256, to: 366, dur: 62 }, { from: 366, to: 392, dur: 26 },
      { from: 392, to: 420, dur: 28 }, { from: 420, to: 420, dur: 16 }],
    cams: [{ at: 0, s: 1 }, { at: 104, s: 1 }, { at: 122, s: 1.35, fx: .5, fy: .27, ty: 1120 }],
    caps: [{ at: 4, text: "第一次跟踪，|只问{三个问题}" }] },
  { key: "order", trans: "fade", step: 1, segs: [
      { from: 236, to: 256, dur: 20 }, { from: 256, to: 318, dur: 30 }, { from: 318, to: 356, dur: 38 },
      { from: 356, to: 400, dur: 44 }, { from: 400, to: 400, dur: 12 }],
    cams: [{ at: 0, s: 1 }, { at: 8, s: 1 }, { at: 24, s: 1.28, fx: .5, fy: .41, ty: 1130 },
      { at: 40, s: 1.28, fx: .5, fy: .41, ty: 1130 }, { at: 54, s: 1.22, fx: .5, fy: .82, ty: 1260 },
      { at: 86, s: 1.22, fx: .5, fy: .82, ty: 1260 }, { at: 100, s: 1 }],
    caps: [{ at: 4, until: 52, text: "按你的仓位上限|分 {3 档}建仓" }, { at: 50, text: "模拟盘{长按即成交}，|不用先授权" }] },
  { key: "watch", trans: "push", step: 2, segs: [
      { from: 94, to: 124, dur: 20 }, { from: 124, to: 140, dur: 16 }, { from: 140, to: 176, dur: 36 },
      { from: 176, to: 218, dur: 42 }, { from: 218, to: 262, dur: 14 }, { from: 262, to: 292, dur: 30 },
      { from: 292, to: 292, dur: 12 }],
    cams: [{ at: 0, s: 1 }, { at: 28, s: 1 }, { at: 44, s: 1.6, fx: .5, fy: .13, ty: 1000 },
      { at: 72, s: 1.6, fx: .5, fy: .13, ty: 1000 }, { at: 90, s: 1.5, fx: .5, fy: .37, ty: 1080 }],
    caps: [{ at: 4, text: "碰到你自己设的{失效线}，|\n第一时间提醒" }] },
  { key: "banner", trans: "push", step: 3, segs: [
      { from: 90, to: 116, dur: 26 }, { from: 116, to: 128, dur: 12 }, { from: 128, to: 190, dur: 58 }],
    cams: [{ at: 0, s: 1 }, { at: 36, s: 1 }, { at: 52, s: 1.6, fx: .5, fy: .13, ty: 1000 }],
    caps: [{ at: 4, text: "{检查日}到了，|复盘自动写好" }] },
  { key: "review", trans: "push", step: 3, segs: [
      { from: 90, to: 146, dur: 56 }, { from: 146, to: 216, dur: 50 }, { from: 216, to: 256, dur: 20 },
      { from: 256, to: 280, dur: 24 }, { from: 280, to: 300, dur: 24 }],
    cams: [{ at: 0, s: 1 }, { at: 8, s: 1 }, { at: 24, s: 1.22, fx: .5, fy: .30, ty: 1120 },
      { at: 54, s: 1.22, fx: .5, fy: .30, ty: 1120 }, { at: 70, s: 1 }, { at: 108, s: 1 },
      { at: 126, s: 1.3, fx: .5, fy: .74, ty: 1180 }],
    caps: [{ at: 4, until: 72, text: "对在哪、错在哪，|{一目了然}" }, { at: 70, text: "每次判断|都成为{可验证的战绩}" }] },
  { key: "theses", trans: "push", step: 3, segs: [{ from: 86, to: 116, dur: 30 }, { from: 116, to: 116, dur: 84 }],
    cams: [{ at: 0, s: 1 }, { at: 26, s: 1 }, { at: 50, s: 1.4, fx: .5, fy: .36, ty: 1100 },
      { at: 114, s: 1.46, fx: .5, fy: .36, ty: 1100 }],
    caps: [{ at: 4, text: "长期积累你的|{命中率}和{校准度}" }] },
];

const HOOK_A = "分析写得再好，\n看完就结束了？";
const HOOK_B = "把分析变成\n{会自己跟进}的观点";
const OUTRO_TITLE = "观点卡";
const OUTRO_STEPS = ["想法", "计划", "跟踪", "复盘"];
const TAGLINE = "Think it. Bobby trades it.";
const BADGE = ["Bobby AI", "观点卡 · iOS 原型"];

export function filmFrameCount(): number {
  return HOOK + BEATS.reduce((sum, beat) => sum + beat.segs.reduce((s, seg) => s + seg.dur, 0), 0) + OUTRO;
}

const esc = (s: string) => s.replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
const gcd = (a: number, b: number): number => (b === 0 ? Math.abs(a) || 1 : gcd(b, a % b));
const sty = (o: Record<string, string | number>) => Object.entries(o).map(([name, value]) => ({ name, value }));

/** Caption markup: each chunk is a span that enters on its own. */
function captionHtml(text: string, cls: string): string {
  let idx = 0;
  const lines = text.split("\n").map(line => line.split("|").filter(Boolean).map(chunk => {
    const body = chunk.replace(/\{([^}]*)\}/g, (_m, hl: string) => `<b>${esc(hl)}</b>`)
      .replace(/^([^<]*)/, (m) => esc(m));
    return `<span class="ch" data-k="${idx++}">${body}</span>`;
  }).join(""));
  return `<div class="${cls}">${lines.map(l => `<div class="ln">${l}</div>`).join("")}</div>`;
}
/** Per-character split for the serif hook and outro lines. */
function charsHtml(text: string, cls: string): string {
  let idx = 0, hl = false;
  const lines = text.split("\n").map(line => [...line].map(ch => {
    if (ch === "{") { hl = true; return ""; }
    if (ch === "}") { hl = false; return ""; }
    return `<span class="c${hl ? " hl" : ""}" data-k="${idx++}">${esc(ch)}</span>`;
  }).join(""));
  return `<div class="${cls}">${lines.map(l => `<div class="ln">${l}</div>`).join("")}</div>`;
}

/* Brand mark: a serif "B" monogram on the brand tile (no generic AI sparkle). */
const mark = (cls: string) => `<div class="mark ${cls}"><b>B</b></div>`;

export function renderThesisFilm(timeline: Timeline, within: SpatialFrame, window: TemporalWindow, fonts: Fonts,
  clips: Record<ClipKey, SynchronizedMedia>, options: FilmOptions) {
  assertTemporalWindowFor(window, { subjectId: options.id, timeline });
  const total = filmFrameCount();
  const length = window.span.endFrameExclusive - window.span.startFrame;
  if (length !== total) throw new Error(`Thesis film needs a ${total}-frame window (${(total / FPS).toFixed(2)} s); got ${length}.`);

  // Beat placement and video sampling.
  let cursor = HOOK;
  const beats = BEATS.map((beat, index) => {
    const dur = beat.segs.reduce((s, seg) => s + seg.dur, 0);
    const start = cursor; cursor += dur;
    const media = clips[beat.key];
    if (media.visual === undefined) throw new Error(`${beat.key} has no picture.`);
    const count = media.frameDomain.frameCount;
    const pieces: { target: { startFrame: number; endFrameExclusive: number }; sourceAtStart: { numerator: number; denominator: number }; rate: { numerator: number; denominator: number } }[] = [];
    const hold = (from: number, a: number, b: number) => { if (b > a) pieces.push({ target: { startFrame: a, endFrameExclusive: b },
      sourceAtStart: { numerator: from, denominator: 1 }, rate: { numerator: 0, denominator: 1 } }); };
    const lead = beat.lead ?? 0;
    hold(beat.segs[0]!.from, start - lead, start);
    let t = start;
    const segInfo: { start: number; end: number; rate: number }[] = [];
    for (const seg of beat.segs) {
      if (seg.to > count || seg.from >= count) throw new Error(`${beat.key} segment ${seg.from}-${seg.to} exceeds ${count} frames.`);
      if (seg.to === seg.from) hold(seg.from, t, t + seg.dur);
      else {
        const g = gcd(seg.to - seg.from, seg.dur);
        pieces.push({ target: { startFrame: t, endFrameExclusive: t + seg.dur }, sourceAtStart: { numerator: seg.from, denominator: 1 },
          rate: { numerator: (seg.to - seg.from) / g, denominator: seg.dur / g } });
      }
      segInfo.push({ start: t, end: t + seg.dur, rate: (seg.to - seg.from) / seg.dur });
      t += seg.dur;
    }
    const last = beat.segs.at(-1)!;
    const tail = index === BEATS.length - 1 ? 34 : TAIL;
    hold(last.to === last.from ? last.to : last.to - 1, t, Math.min(total, t + tail));
    return { ...beat, index, start, end: t, dur, pieces, segInfo, visibleFrom: start - lead, visibleUntil: Math.min(total, t + tail) };
  });

  const videos: VisualElement[] = beats.map(beat => ({
    id: `v-${beat.key}`, parent: "scene", kind: "video", order: 10 + beat.index, muted: true,
    artifact: clips[beat.key].visual!.artifact,
    style: sty({ position: "absolute", left: "0px", top: "0px", width: "100%", height: "100%", "object-fit": "cover" }),
    sourceTime: { sourceFrameRate: timeline.frameRate, sourceFrameCount: clips[beat.key].frameDomain.frameCount, pieces: beat.pieces },
  }) as VisualElement);

  // Every glyph the page draws, so each unicode-range subset is ready before capture.
  const allText = [HOOK_A, HOOK_B, OUTRO_TITLE, ...OUTRO_STEPS, TAGLINE, ...BADGE, "想法计划跟踪复盘快进×.0123456789→B",
    ...BEATS.flatMap(b => [...b.caps.map(c => c.text), b.ring?.label ?? ""])].join("");
  const glyphs = [...new Set([...allText.replace(/[{}|\n]/g, "")])].join("") + "Bobby AI";
  const fontEls: VisualElement[] = (["serif", "sans", "sansm"] as const).map((key, i) => ({
    id: `font-${key}`, parent: "scene", kind: "text", order: 2 + i, text: glyphs, fonts: fonts[key].faces,
    style: sty({ "font-size": "20px", "white-space": "nowrap" }),
  }) as VisualElement);

  const capsHtml = beats.flatMap(beat => beat.caps.map((cap, ci) => captionHtml(cap.text, `cap b${beat.index}c${ci}`))).join("");
  const rails = OUTRO_STEPS.map((s, i) => `<div class="st" data-i="${i}"><i></i><span>${esc(s)}</span></div>${i < 3 ? '<div class="bar"><u></u></div>' : ""}`).join("");
  const html = `
    <div class="bg"><div class="orb o1"></div><div class="orb o2"></div><div class="orb o3"></div></div>
    <div class="phone-wrap"><div class="phone"><div class="btn b1"></div><div class="btn b2"></div><div class="btn b3"></div>
      <div class="body"><div class="screen">${beats.map(b => `<div class="layer" data-i="${b.index}">{{v-${b.key}}}<div class="dim"></div></div>`).join("")}</div></div>
    </div></div>
    <div class="ring"><div class="ring-box"></div><div class="tag"><i></i><span></span></div></div>
    <div class="scrim"></div>
    <div class="rail">${rails}</div>
    <div class="caps">${capsHtml}</div>
    <div class="ff"><svg viewBox="0 0 24 16"><path d="M1 1.5l9.5 6.5L1 14.5zM12 1.5l9.5 6.5-9.5 6.5z" fill="currentColor"/></svg><span>快进</span><em></em></div>
    <div class="badge">${mark("sm")}<span class="bn">${esc(BADGE[0]!)}</span><span class="sep"></span><span class="bs">${esc(BADGE[1]!)}</span></div>
    <div class="hook">
      <div class="kick">${mark("xs")}<span>Bobby AI · 新功能</span></div>
      ${charsHtml(HOOK_A, "ha")}${charsHtml(HOOK_B, "hb")}
    </div>
    <div class="outro">
      ${mark("lg")}
      ${charsHtml(OUTRO_TITLE, "ot")}
      <div class="os">${OUTRO_STEPS.map((s, i) => `<span class="w" data-i="${i}">${esc(s)}</span>${i < 3 ? `<span class="ar" data-i="${i}">→</span>` : ""}`).join("")}</div>
      <div class="tg">${esc(TAGLINE)}</div>
      <div class="ob">${mark("xs")}<span>Bobby AI</span></div>
    </div>
    <div class="fontres">{{font-serif}}{{font-sans}}{{font-sansm}}</div>`;

  const css = `
    :scope{background:#F6F6F8;overflow:hidden;font-synthesis:none;color:#15151A;-webkit-font-smoothing:antialiased}
    .fontres{position:absolute;left:0;top:0;width:4px;height:4px;overflow:hidden;opacity:0}
    .bg{position:absolute;inset:0;background:linear-gradient(180deg,#F8F8FB 0%,#F3F3F7 100%)}
    .orb{position:absolute;border-radius:50%;filter:blur(90px)}
    .o1{width:900px;height:900px;left:-380px;top:-300px;background:radial-gradient(circle,rgba(122,102,255,.30),rgba(122,102,255,0) 68%)}
    .o2{width:1000px;height:1000px;right:-460px;top:780px;background:radial-gradient(circle,rgba(84,161,255,.28),rgba(84,161,255,0) 68%)}
    .o3{width:700px;height:700px;left:-200px;bottom:-380px;background:radial-gradient(circle,rgba(122,102,255,.16),rgba(122,102,255,0) 70%)}
    .phone-wrap{position:absolute;inset:0;transform-origin:540px 1130px;will-change:transform}
    .phone{position:absolute;left:224px;top:462px;width:632px;height:1337px;border-radius:104px;padding:4px;box-sizing:border-box;
      background:linear-gradient(150deg,#FBFBFD 0%,#D6D6DE 40%,#C2C2CC 70%,#ECECF1 100%);transform-origin:0 0;
      box-shadow:0 70px 120px -40px rgba(52,38,140,.38),0 30px 60px -30px rgba(20,20,40,.30),inset 0 0 0 1px rgba(255,255,255,.6)}
    .btn{position:absolute;width:6px;border-radius:3px;background:linear-gradient(90deg,#B9B9C3,#E3E3EA)}
    .b1{left:-5px;top:250px;height:62px}.b2{left:-5px;top:340px;height:110px}.b3{right:-5px;top:300px;height:160px;background:linear-gradient(270deg,#B9B9C3,#E3E3EA)}
    .body{width:100%;height:100%;border-radius:100px;background:#0A0A0D;padding:12px;box-sizing:border-box}
    .screen{position:relative;width:600px;height:1305px;border-radius:88px;overflow:hidden;background:#F6F6F8;isolation:isolate;transform:translateZ(0)}
    .layer{position:absolute;inset:0;visibility:hidden}
    .dim{position:absolute;inset:0;background:#0B0B14;opacity:0}
    .scrim{position:absolute;left:0;top:0;width:100%;height:560px;opacity:0;
      background:linear-gradient(180deg,rgba(247,246,250,1) 0%,rgba(247,246,250,1) 74%,rgba(247,246,250,0) 100%)}
    .rail{position:absolute;left:0;right:0;top:96px;display:flex;align-items:center;justify-content:center;gap:0;font-family:var(--sansm);font-size:27px;letter-spacing:2px;color:#A3A3AF}
    .st{display:flex;align-items:center;gap:12px}
    .st i{width:12px;height:12px;border-radius:50%;background:#D3D3DC;box-shadow:0 0 0 0 rgba(122,102,255,0)}
    .bar{width:74px;height:2px;margin:0 20px;background:#DCDCE4;border-radius:2px;overflow:hidden}
    .bar u{display:block;height:100%;width:0;background:linear-gradient(90deg,#7A66FF,#54A1FF)}
    .caps{position:absolute;left:60px;right:60px;top:170px;height:270px}
    .cap{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;visibility:hidden}
    .cap .ln{font-family:var(--sans);font-size:66px;line-height:1.28;letter-spacing:1px;white-space:nowrap;text-align:center}
    .ch{display:inline-block;opacity:0}
    .cap b,.hl{font-weight:inherit;background:linear-gradient(100deg,#7A66FF 10%,#54A1FF 95%);-webkit-background-clip:text;background-clip:text;color:transparent}
    .ring{position:absolute;inset:0;opacity:0}
    .ring-box{position:absolute;border-radius:30px;border:3px solid #7A66FF;box-shadow:0 0 0 8px rgba(122,102,255,.14),0 0 40px rgba(122,102,255,.28)}
    .tag{position:absolute;left:50%;transform:translateX(-50%);display:flex;align-items:center;gap:16px;padding:20px 34px;border-radius:999px;white-space:nowrap;
      background:rgba(255,255,255,.96);box-shadow:0 24px 50px -16px rgba(52,38,140,.40),0 0 0 1px rgba(122,102,255,.18);font-family:var(--sans);font-size:38px;color:#15151A}
    .tag i{width:16px;height:16px;border-radius:50%;background:linear-gradient(135deg,#7A66FF,#54A1FF);box-shadow:0 0 0 6px rgba(122,102,255,.15)}
    .tag:before{content:"";position:absolute;left:50%;top:-11px;width:22px;height:22px;margin-left:-11px;background:#fff;transform:rotate(45deg);border-radius:4px 0 0 0;box-shadow:-1px -1px 0 rgba(122,102,255,.18)}
    .ff{position:absolute;right:226px;top:410px;display:flex;align-items:center;gap:10px;padding:9px 18px;border-radius:999px;opacity:0;
      background:rgba(21,21,26,.82);color:#fff;font-family:var(--sansm);font-size:24px;letter-spacing:1px}
    .ff svg{width:24px;height:16px;color:#9FC6FF}.ff em{font-style:normal;font-family:var(--sans);color:#C9C0FF}
    .badge{position:absolute;left:50%;top:1832px;transform:translateX(-50%);display:flex;align-items:center;gap:14px;padding:12px 26px 12px 14px;border-radius:999px;
      background:rgba(255,255,255,.78);box-shadow:0 10px 30px -12px rgba(40,30,110,.25),0 0 0 1px rgba(20,20,40,.05);white-space:nowrap;opacity:0}
    .bn{font-family:var(--sans);font-size:26px;color:#15151A}.bs{font-family:var(--sansm);font-size:24px;color:#6E6E7A}
    .sep{width:5px;height:5px;border-radius:50%;background:#B8B8C4}
    .mark{position:relative;border-radius:28%;background:linear-gradient(135deg,#7A66FF 0%,#6C82FF 45%,#54A1FF 100%);
      box-shadow:inset 0 1px 0 rgba(255,255,255,.35),0 10px 26px -8px rgba(92,96,255,.55);display:flex;align-items:center;justify-content:center}
    .mark b{font-family:var(--serif);font-weight:600;color:#fff;line-height:1;transform:translateY(-3%)}
    .mark.xs b{font-size:28px}.mark.sm b{font-size:27px}.mark.lg b{font-size:112px}
    .mark.xs{width:44px;height:44px}.mark.sm{width:42px;height:42px}.mark.lg{width:176px;height:176px;border-radius:30%;box-shadow:inset 0 2px 0 rgba(255,255,255,.35),0 40px 80px -24px rgba(92,96,255,.6)}
    .hook{position:absolute;inset:0}
    .kick{position:absolute;left:0;right:0;top:470px;display:flex;align-items:center;justify-content:center;gap:16px;font-family:var(--sansm);font-size:30px;color:#6E6E7A;letter-spacing:3px;opacity:0}
    .ha,.hb{position:absolute;left:40px;right:40px;text-align:center;font-family:var(--serif);color:#15151A}
    .ha{top:690px;font-size:84px;line-height:1.36}
    .hb{top:1000px;font-size:92px;line-height:1.34}
    .ha .ln,.hb .ln,.ot .ln{white-space:nowrap}
    .c{display:inline-block;opacity:0}
    .outro{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center}
    .outro .mark.lg{position:absolute;top:580px;left:452px;opacity:0}
    .ot{position:absolute;top:820px;left:0;right:0;text-align:center;font-family:var(--serif);font-size:188px;line-height:1.1;letter-spacing:18px;padding-left:18px}
    .os{position:absolute;top:1100px;left:0;right:0;display:flex;justify-content:center;align-items:center;gap:22px;font-family:var(--sansm);font-size:46px;color:#3B3B46;letter-spacing:2px}
    .os .w,.os .ar{opacity:0;display:inline-block}.os .ar{color:#8F86FF;font-size:40px}
    .tg{position:absolute;top:1248px;left:0;right:0;text-align:center;font-family:var(--sans);font-size:44px;letter-spacing:.5px;opacity:0;
      background:linear-gradient(100deg,#7A66FF 30%,#54A1FF 70%);-webkit-background-clip:text;background-clip:text;color:transparent}
    .ob{position:absolute;top:1760px;left:0;right:0;display:flex;justify-content:center;align-items:center;gap:14px;font-family:var(--sans);font-size:30px;color:#15151A;opacity:0}`;

  const data = {
    total, hook: HOOK, outro: total - OUTRO,
    phone: { ox: 224, oy: 462, sx: 240, sy: 478, sw: 600, sh: 1305, cx: 540, cy: 1130 },
    beats: beats.map(b => ({ key: b.key, start: b.start, end: b.end, trans: b.trans, step: b.step,
      visibleFrom: b.visibleFrom, visibleUntil: b.visibleUntil, cams: b.cams, segs: b.segInfo,
      caps: b.caps.map((c, i) => ({ at: b.start + c.at, until: b.start + (c.until ?? b.dur), cls: `b${b.index}c${i}` })),
      ring: b.ring ? { ...b.ring, at: b.start + b.ring.at } : null })),
  };

  return sealVisualTrack({ id: options.id, timelineId: timeline.id, visualIr: "hypit.visual-ir@1",
    presents: [{ id: options.id, order: 0, z: options.z, span: window.span,
      elements: [{ id: "scene", kind: "program", order: 0,
        program: htmlVisual({ html, css, data, setup: `const __name = (f) => f; return (${setup.toString()})(root, data);` }),
        style: sty({ position: "absolute", left: `${within.xPx}px`, top: `${within.yPx}px`, width: `${within.widthPx}px`, height: `${within.heightPx}px` }),
      } as VisualElement, ...fontEls, ...videos] }] });
}

/* Runs in the renderer page. Everything is computed from the frame number, so any frame can be drawn directly. */
function setup(root: any, data: any) {
  const q = (s: string) => root.querySelector(s), qa = (s: string) => [...root.querySelectorAll(s)];
  const fam = (id: number) => getComputedStyle(q(".fontres").children[id]).fontFamily;
  root.style.setProperty("--serif", fam(0)); root.style.setProperty("--sans", fam(1)); root.style.setProperty("--sansm", fam(2));
  const clamp = (v: number, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const lin = (f: number, a: number, b: number) => clamp((f - a) / (b - a));
  const eio = (t: number) => (t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
  const eout = (t: number) => 1 - Math.pow(1 - t, 3);
  const eback = (t: number) => { const c = 1.5; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); };
  const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
  const P = data.phone;
  const wrap = q(".phone-wrap"), phone = q(".phone"), scrim = q(".scrim"), rail = q(".rail"), ff = q(".ff"), ffRate = q(".ff em"),
    badge = q(".badge"), ring = q(".ring"), ringBox = q(".ring-box"), tag = q(".tag"), tagText = q(".tag span");
  const layers = qa(".layer"), dims = qa(".layer .dim"), steps = qa(".rail .st"), bars = qa(".rail .bar u");
  const caps = data.beats.flatMap((b: any) => b.caps.map((c: any) => ({ ...c, el: q("." + c.cls), chunks: qa("." + c.cls + " .ch") })));
  const ha = qa(".ha .c"), hb = qa(".hb .c"), kick = q(".kick"), haBox = q(".ha"), hook = q(".hook");
  const outro = q(".outro"), omark = q(".outro .mark"), ot = qa(".ot .c"), ow = qa(".os .w"), oa = qa(".os .ar"), tg = q(".tg"), ob = q(".ob");

  const rest = { s: 1, px: P.cx, py: P.cy, tx: P.cx, ty: P.cy };
  const camKey = (k: any) => k.s === 1 && k.fx === undefined ? rest :
    { s: k.s, px: P.sx + k.fx * P.sw, py: P.sy + k.fy * P.sh, tx: P.cx, ty: k.ty ?? (P.sy + k.fy * P.sh) };
  const mix = (a: any, b: any, t: number) => ({ s: lerp(a.s, b.s, t), px: lerp(a.px, b.px, t), py: lerp(a.py, b.py, t), tx: lerp(a.tx, b.tx, t), ty: lerp(a.ty, b.ty, t) });
  const camIn = (beat: any, local: number) => {
    const ks = beat.cams;
    if (!ks.length) return rest;
    if (local <= ks[0].at) return camKey(ks[0]);
    for (let i = 1; i < ks.length; i++) if (local <= ks[i].at) return mix(camKey(ks[i - 1]), camKey(ks[i]), eio(lin(local, ks[i - 1].at, ks[i].at)));
    return camKey(ks[ks.length - 1]);
  };
  const BLEND = 18;
  const camAt = (f: number) => {
    const i = data.beats.findIndex((b: any) => f >= b.start && f < b.end);
    if (i < 0) return f < data.hook ? rest : camIn(data.beats[data.beats.length - 1], data.beats[data.beats.length - 1].end);
    const b = data.beats[i], local = f - b.start, cur = camIn(b, local);
    if (i > 0 && local < BLEND) return mix(camIn(data.beats[i - 1], data.beats[i - 1].end - data.beats[i - 1].start), cur, eio(local / BLEND));
    return cur;
  };
  const toCanvas = (c: any, x: number, y: number) => ({ x: c.tx + c.s * (x - c.px), y: c.ty + c.s * (y - c.py) });

  return (frame: number) => {
    const f = frame;
    /* Background drift */
    q(".o1").style.transform = `translate(${Math.sin(f / 90) * 40}px,${Math.cos(f / 110) * 30}px)`;
    q(".o2").style.transform = `translate(${Math.cos(f / 100) * 50}px,${Math.sin(f / 80) * 36}px)`;

    /* Hook */
    const hookOut = eio(lin(f, data.hook - 30, data.hook - 12));
    hook.style.visibility = f < data.hook ? "visible" : "hidden";
    hook.style.opacity = String(1 - hookOut); hook.style.transform = `translateY(${-90 * hookOut}px)`;
    kick.style.opacity = String(eout(lin(f, 2, 16)) * (1 - .0));
    kick.style.transform = `translateY(${14 * (1 - eout(lin(f, 2, 16)))}px)`;
    ha.forEach((el: any, k: number) => { const t = eout(lin(f, 4 + k * 1.3, 16 + k * 1.3));
      el.style.opacity = String(t); el.style.transform = `translateY(${30 * (1 - t)}px)`; el.style.filter = `blur(${6 * (1 - t)}px)`; });
    const dimA = eio(lin(f, 40, 54));
    haBox.style.color = `rgb(${lerp(21, 160, dimA)},${lerp(21, 160, dimA)},${lerp(26, 172, dimA)})`;
    haBox.style.transform = `translateY(${-130 * dimA}px) scale(${1 - .14 * dimA})`;
    hb.forEach((el: any, k: number) => { const t = eout(lin(f, 46 + k * 1.4, 60 + k * 1.4));
      el.style.opacity = String(t); el.style.transform = `translateY(${36 * (1 - t)}px)`; el.style.filter = `blur(${7 * (1 - t)}px)`; });
    q(".hb").style.transform = `translateY(${-130 * dimA}px)`;

    /* Phone entrance and exit */
    const enter = eout(lin(f, data.hook - 20, data.hook + 8));
    const exit = eio(lin(f, data.outro, data.outro + 20));
    wrap.style.opacity = String(Math.min(enter, 1 - exit));
    wrap.style.transform = `translateY(${(1 - enter) * 820 + exit * 260}px) scale(${lerp(.96, 1, enter) * lerp(1, .9, exit)})`;
    wrap.style.visibility = enter <= 0 || exit >= 1 ? "hidden" : "visible";

    /* Camera */
    const c = camAt(f);
    const tx = c.tx - P.ox + c.s * (P.ox - c.px), ty = c.ty - P.oy + c.s * (P.oy - c.py);
    phone.style.transform = `translate(${tx}px,${ty}px) scale(${c.s})`;
    const zoomK = clamp((c.s - 1) / .12);
    scrim.style.opacity = String(zoomK * (1 - exit));

    /* Recordings: visibility and transitions */
    data.beats.forEach((b: any, i: number) => {
      const el = layers[i], vis = f >= b.visibleFrom && f < b.visibleUntil;
      el.style.visibility = vis ? "visible" : "hidden";
      if (!vis) return;
      el.style.zIndex = String(i + 1);
      let x = 0, op = 1;
      const local = f - b.start;
      if (b.trans === "push" && local < 18) x = 600 * (1 - eio(clamp(local / 18)));
      if (b.trans === "fade" && local < 12) op = eio(clamp(local / 12));
      const next = data.beats[i + 1];
      let d = 0;
      if (next && f >= next.start && next.trans === "push") { const t = eio(clamp((f - next.start) / 18)); x = -180 * t; d = .22 * t; }
      el.style.transform = `translateX(${x}px)`; el.style.opacity = String(op);
      dims[i].style.opacity = String(d);
    });

    /* Step rail */
    const bi = data.beats.findIndex((b: any) => f >= b.start && f < b.end);
    const beat = bi >= 0 ? data.beats[bi] : null;
    const railIn = eout(lin(f, data.hook, data.hook + 14)) * (1 - eio(lin(f, data.outro, data.outro + 14)));
    rail.style.opacity = String(railIn); rail.style.transform = `translateY(${-14 * (1 - railIn)}px)`;
    badge.style.opacity = String(railIn * (1 - zoomK));
    const stepNow = (g: number) => { const k = data.beats.findIndex((b: any) => g >= b.start && g < b.end); return k < 0 ? (g >= data.outro ? 3 : -1) : data.beats[k].step; };
    const cur = stepNow(f);
    const since = beat ? f - beat.start : 99;
    const prevStep = beat && bi > 0 ? data.beats[bi - 1].step : -1;
    steps.forEach((el: any, k: number) => {
      const dot = el.querySelector("i"), label = el.querySelector("span");
      const on = k === cur, past = k < cur;
      const pop = on && prevStep !== cur ? eback(clamp(since / 12)) : 1;
      dot.style.background = on || past ? "linear-gradient(135deg,#7A66FF,#54A1FF)" : "#D3D3DC";
      dot.style.transform = `scale(${on ? 1.25 * pop : 1})`;
      dot.style.boxShadow = on ? "0 0 0 7px rgba(122,102,255,.16)" : "none";
      label.style.color = on ? "#15151A" : past ? "#7A66FF" : "#A3A3AF";
    });
    bars.forEach((el: any, k: number) => {
      let w = k < cur ? 1 : 0;
      if (k === cur - 1 && prevStep !== cur) w = eio(clamp(since / 14));
      el.style.width = `${w * 100}%`;
    });

    /* Captions */
    caps.forEach((cp: any) => {
      const on = f >= cp.at - 1 && f < cp.until;
      cp.el.style.visibility = on ? "visible" : "hidden";
      if (!on) return;
      const out = eio(lin(f, cp.until - 9, cp.until - 1));
      cp.el.style.opacity = String(1 - out); cp.el.style.transform = `translateY(${-18 * out}px)`;
      cp.chunks.forEach((el: any, k: number) => {
        const t = eout(lin(f, cp.at + k * 4, cp.at + k * 4 + 12));
        el.style.opacity = String(t); el.style.transform = `translateY(${34 * (1 - t)}px)`; el.style.filter = `blur(${8 * (1 - t)}px)`;
      });
    });

    /* Fast-forward indicator */
    let rate = 0;
    if (beat) for (const s of beat.segs) if (f >= s.start && f < s.end) rate = s.rate;
    let ffOn = 0;
    if (beat) for (const s of beat.segs) if (s.rate >= 1.5) ffOn = Math.max(ffOn, Math.min(eout(lin(f, s.start, s.start + 5)), 1 - eio(lin(f, s.end - 5, s.end))));
    ff.style.opacity = String(ffOn);
    if (rate >= 1.5) ffRate.textContent = `${rate.toFixed(1)}×`;

    /* Ring callout */
    const rb = data.beats.find((b: any) => b.ring && f >= b.ring.at - 2 && f < b.end + 6);
    if (rb) {
      const r = rb.ring, cam = camIn(rb, r.at - rb.start);
      const a = toCanvas(cam, P.sx + r.x0 * P.sw, P.sy + r.y0 * P.sh), z = toCanvas(cam, P.sx + r.x1 * P.sw, P.sy + r.y1 * P.sh);
      const t = eout(lin(f, r.at, r.at + 12)), o = 1 - eio(lin(f, rb.end - 4, rb.end + 6));
      ring.style.opacity = String(Math.min(t, o));
      Object.assign(ringBox.style, { left: `${a.x}px`, top: `${a.y}px`, width: `${z.x - a.x}px`, height: `${z.y - a.y}px`, transform: `scale(${lerp(1.06, 1, t)})` });
      tag.style.top = `${z.y + 34}px`;
      const tt = eback(clamp((f - r.at - 6) / 14));
      tag.style.transform = `translateX(-50%) translateY(${(1 - tt) * 24}px) scale(${lerp(.9, 1, clamp(tt))})`;
      tag.style.opacity = String(clamp((f - r.at - 6) / 8));
      if (tagText.textContent !== r.label) tagText.textContent = r.label;
    } else ring.style.opacity = "0";

    /* Outro */
    const ol = f - data.outro - 12;
    outro.style.visibility = f >= data.outro ? "visible" : "hidden";
    if (f >= data.outro) {
      const m = eback(clamp((ol - 10) / 18));
      omark.style.opacity = String(clamp((ol - 10) / 8)); omark.style.transform = `scale(${lerp(.6, 1, m)}) rotate(${(1 - clamp(m)) * -12}deg)`;
      ot.forEach((el: any, k: number) => { const t = eout(lin(ol, 22 + k * 4, 40 + k * 4));
        el.style.opacity = String(t); el.style.transform = `translateY(${50 * (1 - t)}px)`; el.style.filter = `blur(${10 * (1 - t)}px)`; });
      ow.forEach((el: any, k: number) => { const t = eout(lin(ol, 44 + k * 7, 56 + k * 7));
        el.style.opacity = String(t); el.style.transform = `translateY(${18 * (1 - t)}px)`; });
      oa.forEach((el: any, k: number) => { const t = eout(lin(ol, 48 + k * 7, 58 + k * 7));
        el.style.opacity = String(t); el.style.transform = `translateX(${-14 * (1 - t)}px)`; });
      const tgT = eout(lin(ol, 78, 94));
      tg.style.opacity = String(tgT); tg.style.transform = `translateY(${16 * (1 - tgT)}px)`;
      const obT = eout(lin(ol, 86, 100));
      ob.style.opacity = String(obT);
    }
  };
}
