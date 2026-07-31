import { AnimatePresence, motion } from "framer-motion";
import { Download, ExternalLink, Github, Menu, MessageSquare, Moon, ShieldCheck, Sun, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { ControlCard, Header, StatusBar } from "./components/chrome";
import Globe from "./components/Globe";
import IpWidget from "./components/IpWidget";
import NodesDrawer from "./components/NodesDrawer";
import SettingsDrawer from "./components/SettingsDrawer";
import SubscriptionDrawer from "./components/SubscriptionDrawer";
import { ThemeProvider, useTheme } from "./lib/theme";
import { fmtNow, uid, type ConnState, type Mode, type NodeT, type Sub } from "./lib/ui";

/* ---------------------------------- mock data ---------------------------------- */

const DEFAULT_SUBS: Sub[] = [
  { id: "main", name: "Main", url: "https://sub.example.com/main.yaml", updated: "2025-07-28 12:30", active: true },
  { id: "backup", name: "备用订阅", url: "https://sub.example.com/backup.yaml", updated: "2025-07-25 09:41", active: false },
  { id: "airport", name: "机场订阅", url: "https://sub.example.com/airport.yaml", updated: "2025-07-20 18:22", active: false },
  { id: "lab", name: "测试订阅", url: "https://sub.example.com/test.yaml", updated: "2025-07-18 16:05", active: false },
];

const BASE_NODES: Omit<NodeT, "id" | "testing">[] = [
  { country: "日本", name: "Tokyo-01", code: "JP", proto: "Shadowsocks", transport: "UDP", latency: 68 },
  { country: "美国", name: "Los Angeles-02", code: "US", proto: "Shadowsocks", transport: "UDP", latency: 153 },
  { country: "新加坡", name: "Singapore-01", code: "SG", proto: "Vmess", transport: "TCP", latency: 112 },
  { country: "德国", name: "Frankfurt-01", code: "DE", proto: "Vmess", transport: "TCP", latency: 86 },
  { country: "香港", name: "Hong Kong-01", code: "HK", proto: "Trojan", transport: "TCP", latency: 65 },
  { country: "英国", name: "London-01", code: "GB", proto: "Shadowsocks", transport: "UDP", latency: 128 },
];

function makeNodes(subId: string): NodeT[] {
  if (subId === "main") return BASE_NODES.map((n, i) => ({ ...n, id: n.code.toLowerCase() + i }));
  return BASE_NODES.map((n, i) => ({
    ...n,
    id: `${subId}-${i}`,
    name: n.name.replace(/-\d+$/, `-${String((i % 3) + 1).padStart(2, "0")}`),
    latency: Math.round(42 + Math.random() * 150),
  }));
}

const randomLatency = () => (Math.random() < 0.08 ? null : Math.round(30 + Math.random() * 190));

type DrawerKind = "none" | "nodes" | "subs" | "settings";

const PROJECT_URL = "https://github.com/WEP-56/FLsing";
const RELEASES_URL = `${PROJECT_URL}/releases`;
const ISSUES_URL = `${PROJECT_URL}/issues`;

function ProjectLinks({ compact = false }: { compact?: boolean }) {
  const actions = [
    { href: RELEASES_URL, label: "下载 Release", icon: Download },
    { href: PROJECT_URL, label: "仓库", icon: Github },
    { href: ISSUES_URL, label: "反馈", icon: MessageSquare },
  ];

  return (
    <div className={compact ? "flex flex-col gap-1.5" : "flex items-center gap-1.5"}>
      {actions.map(({ href, label, icon: Icon }) => (
        <a
          key={href}
          href={href}
          target="_blank"
          rel="noreferrer"
          className={
            compact
              ? "hov t2 flex items-center gap-2 rounded-lg px-3 py-2 text-[12px] transition-colors"
              : "hov t3 flex items-center gap-1.5 rounded-full border bd1 px-3 py-1.5 text-[11px] font-medium transition-colors"
          }
        >
          <Icon size={compact ? 15 : 12.5} strokeWidth={1.9} />
          <span>{label}</span>
        </a>
      ))}
    </div>
  );
}

/* ------------------------------------- app ------------------------------------- */

export default function App() {
  return (
    <ThemeProvider>
      <Preview />
    </ThemeProvider>
  );
}

function Preview() {
  const { theme, toggle } = useTheme();
  const [conn, setConn] = useState<ConnState>("idle");
  const [seconds, setSeconds] = useState(0);
  const [mode, setMode] = useState<Mode>("rule");
  const [subs, setSubs] = useState<Sub[]>(DEFAULT_SUBS);
  const [nodeMap, setNodeMap] = useState<Record<string, NodeT[]>>({ main: makeNodes("main") });
  const [currentId, setCurrentId] = useState("jp0");
  const [drawer, setDrawer] = useState<DrawerKind>("none");
  const [lastUpdate, setLastUpdate] = useState("2025-07-28 12:30");
  const [updatingIds, setUpdatingIds] = useState<string[]>([]);
  const [toast, setToast] = useState<{ id: number; msg: string } | null>(null);
  const [siteMenuOpen, setSiteMenuOpen] = useState(false);
  const [showDisclaimer, setShowDisclaimer] = useState(false);

  const connTimer = useRef<number | undefined>(undefined);
  const toastTimer = useRef<number | undefined>(undefined);

  const activeSub = subs.find((s) => s.active) ?? null;
  const nodes = (activeSub && nodeMap[activeSub.id]) || [];
  const currentNode = nodes.find((n) => n.id === currentId) ?? nodes[0] ?? null;

  const showToast = useCallback((msg: string) => {
    window.clearTimeout(toastTimer.current);
    setToast({ id: Date.now(), msg });
    toastTimer.current = window.setTimeout(() => setToast(null), 2200);
  }, []);

  useEffect(() => {
    if (conn !== "connected") return;
    const id = window.setInterval(() => setSeconds((s) => s + 1), 1000);
    return () => window.clearInterval(id);
  }, [conn]);

  const scheduleConnected = (ms: number) => {
    window.clearTimeout(connTimer.current);
    connTimer.current = window.setTimeout(() => {
      setConn("connected");
      setSeconds(0);
    }, ms);
  };

  const toggleConnect = () => {
    if (conn === "connected") {
      window.clearTimeout(connTimer.current);
      setConn("idle");
      setSeconds(0);
      return;
    }
    if (conn === "connecting") {
      window.clearTimeout(connTimer.current);
      setConn("idle");
      return;
    }
    if (!currentNode) {
      showToast("请先添加订阅");
      setDrawer("subs");
      return;
    }
    setConn("connecting");
    scheduleConnected(2100);
  };

  const selectNode = (id: string) => {
    setCurrentId(id);
    if (conn === "connected" || conn === "connecting") {
      const n = nodes.find((x) => x.id === id);
      setConn("connecting");
      scheduleConnected(1100);
      if (n) showToast(`已切换至 ${n.country}｜${n.name}`);
    }
  };

  /* ---- subscriptions ---- */

  const ensureNodes = (subId: string) => setNodeMap((m) => (m[subId] ? m : { ...m, [subId]: makeNodes(subId) }));

  const enableSub = (id: string) => {
    const target = subs.find((s) => s.id === id);
    const wasActive = !!target?.active;
    setSubs((ss) => ss.map((s) => ({ ...s, active: wasActive ? false : s.id === id })));
    if (!wasActive) {
      ensureNodes(id);
      const list = nodeMap[id] ?? makeNodes(id);
      setCurrentId(list[0]?.id ?? "");
      setLastUpdate(target?.updated ?? fmtNow());
    }
    if (target) showToast(wasActive ? `「${target.name}」已停用` : `已启用「${target.name}」`);
  };

  const switchSub = (id: string) => {
    if (id === activeSub?.id) return;
    setSubs((ss) => ss.map((s) => ({ ...s, active: s.id === id })));
    ensureNodes(id);
    const list = nodeMap[id] ?? makeNodes(id);
    setCurrentId(list[0]?.id ?? "");
    showToast(`已切换至「${subs.find((s) => s.id === id)?.name ?? ""}」`);
  };

  const addSub = (name: string, url: string) => {
    setSubs((ss) => [...ss, { id: uid(), name, url, updated: fmtNow(), active: false }]);
    showToast("已添加订阅");
  };

  const editSub = (id: string, name: string, url: string) => {
    setSubs((ss) => ss.map((s) => (s.id === id ? { ...s, name, url } : s)));
    showToast("已保存");
  };

  const updateSub = (id: string) => {
    setUpdatingIds((u) => [...u, id]);
    window.setTimeout(() => {
      setUpdatingIds((u) => u.filter((x) => x !== id));
      setSubs((ss) => ss.map((s) => (s.id === id ? { ...s, updated: fmtNow() } : s)));
      if (activeSub?.id === id) refreshNodes(true);
      showToast("订阅已更新");
    }, 1200);
  };

  const deleteSub = (id: string) => {
    setSubs((ss) => {
      const next = ss.filter((s) => s.id !== id);
      if (ss.find((s) => s.id === id)?.active && next.length) next[0] = { ...next[0], active: true };
      return next;
    });
    showToast("已删除订阅");
  };

  /* ---- nodes ---- */

  const patchNode = (subId: string, id: string, patch: Partial<NodeT>) =>
    setNodeMap((m) => ({ ...m, [subId]: (m[subId] ?? []).map((n) => (n.id === id ? { ...n, ...patch } : n)) }));

  const testNode = (id: string) => {
    if (!activeSub) return;
    patchNode(activeSub.id, id, { testing: true });
    window.setTimeout(
      () => patchNode(activeSub.id, id, { testing: false, latency: randomLatency() }),
      650 + Math.random() * 750,
    );
  };

  const testAll = () => {
    if (!activeSub) return;
    nodes.forEach((n, i) => {
      patchNode(activeSub.id, n.id, { testing: true });
      window.setTimeout(
        () => patchNode(activeSub.id, n.id, { testing: false, latency: randomLatency() }),
        600 + i * 160 + Math.random() * 500,
      );
    });
  };

  const refreshNodes = (silent = false) => {
    if (!activeSub) return;
    setNodeMap((m) => ({
      ...m,
      [activeSub.id]: (m[activeSub.id] ?? []).map((n) => ({ ...n, testing: false, latency: randomLatency() })),
    }));
    setLastUpdate(fmtNow());
    if (!silent) showToast("节点已更新");
  };

  /* ---------------------------------- render ---------------------------------- */

  return (
    <div
      className="relative flex min-h-[100dvh] select-none items-center justify-center overflow-hidden transition-colors duration-500"
      style={{ background: "var(--stage)" }}
    >
      {/* ambient glow */}
      <div
        aria-hidden
        className="pointer-events-none absolute left-1/2 top-1/2 hidden h-[1100px] w-[1100px] -translate-x-1/2 -translate-y-1/2 rounded-full sm:block"
        style={{
          background:
            theme === "dark"
              ? "radial-gradient(closest-side, rgba(255,255,255,0.045), transparent)"
              : "radial-gradient(closest-side, rgba(255,255,255,0.75), transparent)",
        }}
      />

      {/* product links live outside the mobile-app mockup */}
      <nav className="absolute inset-x-0 top-6 z-30 hidden items-center justify-center sm:flex">
        <div className="sf0 flex items-center gap-3 rounded-full border bd1 px-3 py-2 backdrop-blur-md">
          <div className="t2 flex items-center gap-2 px-1 text-[11px] font-semibold tracking-[0.14em]">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: "var(--accent)" }} />
            FLSING PREVIEW
          </div>
          <span className="h-3.5 w-px" style={{ background: "var(--bd2)" }} />
          <ProjectLinks />
        </div>
      </nav>

      <div className="absolute left-4 top-11 z-[100] sm:hidden">
        <button
          onClick={() => setSiteMenuOpen((open) => !open)}
          aria-label="打开预览站导航"
          aria-expanded={siteMenuOpen}
          className="sf1 t2 grid h-9 w-9 place-items-center rounded-full border bd1 backdrop-blur-md"
        >
          {siteMenuOpen ? <X size={16} /> : <Menu size={17} />}
        </button>
        <AnimatePresence>
          {siteMenuOpen && (
            <motion.div
              initial={{ opacity: 0, y: -6, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -4, scale: 0.97 }}
              transition={{ duration: 0.18 }}
              className="sf1 absolute left-0 top-11 w-36 rounded-xl border bd1 p-1.5 shadow-2xl backdrop-blur-xl"
            >
              <ProjectLinks compact />
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* desktop-only theme switch (not part of the app UI) */}
      <button
        onClick={toggle}
        aria-label="切换深浅模式"
        className="sf1 hov t2 absolute right-8 top-8 z-20 hidden items-center gap-2 rounded-full border bd1 py-2 pl-3 pr-3.5 text-[12px] backdrop-blur-md transition-all active:scale-95 sm:flex"
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.span
            key={theme}
            initial={{ opacity: 0, rotate: -60, scale: 0.6 }}
            animate={{ opacity: 1, rotate: 0, scale: 1 }}
            exit={{ opacity: 0, rotate: 60, scale: 0.6 }}
            transition={{ duration: 0.24 }}
            className="grid place-items-center"
          >
            {theme === "dark" ? <Moon size={14} strokeWidth={1.9} /> : <Sun size={14} strokeWidth={1.9} />}
          </motion.span>
        </AnimatePresence>
        {theme === "dark" ? "深色" : "浅色"}
      </button>

      {/* bottom caption */}
      <div className="t6 absolute inset-x-0 bottom-5 hidden items-center justify-center gap-2 text-[10.5px] tracking-[0.06em] sm:flex">
        <span className="select-none">交互式设计预览，不创建 VPN 连接或处理真实订阅</span>
        <button
          onClick={() => setShowDisclaimer(true)}
          className="hov-t pointer-events-auto inline-flex items-center gap-1 rounded px-1.5 py-1 text-[10.5px] transition-colors"
        >
          <ShieldCheck size={12} />
          免责声明
        </button>
      </div>

      {/* side annotations */}
      <aside className="pointer-events-none absolute left-12 top-1/2 hidden -translate-y-1/2 space-y-7 xl:block">
        <div>
          <div className="t6 mb-3 text-[10px] font-semibold tracking-[0.3em]">主题令牌</div>
          <div className="t5 space-y-2.5 text-[11px]">
            {[
              ["--page", theme === "dark" ? "#000000" : "#EAE8E3"],
              ["--sheet", theme === "dark" ? "#0B0B0B" : "#F4F3EF"],
              ["--accent", theme === "dark" ? "#30D158" : "#178B3F"],
            ].map(([name, hex], i) => (
              <div key={i} className="flex items-center gap-2.5">
                <span className="h-3 w-3 rounded-full border bd2" style={{ background: hex }} />
                <span className="tnum">{hex}</span>
                <span className="t6">{name}</span>
              </div>
            ))}
          </div>
        </div>
        <div>
          <div className="t6 mb-3 text-[10px] font-semibold tracking-[0.3em]">动画曲线</div>
          <div className="t5 space-y-2.5 text-[11px]">
            <div>200 – 350 ms · 慢、轻、自然</div>
            <div className="t6">Fade / Slide / Scale</div>
          </div>
        </div>
      </aside>

      <aside className="pointer-events-none absolute right-12 top-1/2 hidden -translate-y-1/2 space-y-7 text-right xl:block">
        <div>
          <div className="t6 mb-3 text-[10px] font-semibold tracking-[0.3em]">布局原则</div>
          <div className="t5 space-y-2.5 text-[11px]">
            <div>Header → 地球可视化 → 控制区</div>
            <div className="t6">无流量统计 · 无日志 · 无复杂状态</div>
          </div>
        </div>
        <div>
          <div className="t6 mb-3 text-[10px] font-semibold tracking-[0.3em]">功能层级</div>
          <div className="t5 space-y-2.5 text-[11px]">
            <div>Full Drawer — 设置</div>
            <div>Partial Drawer — 订阅 / 节点</div>
          </div>
        </div>
      </aside>

      {/* ------------------------------- phone frame ------------------------------- */}
      <div
        className="relative z-10 h-[100dvh] w-full transition-colors duration-500 sm:h-[min(872px,92vh)] sm:w-[404px] sm:rounded-[46px] sm:border sm:p-[11px]"
        style={{
          background: "var(--frame)",
          borderColor: "var(--frame-bd)",
          boxShadow: "var(--shadow-frame)",
        }}
      >
        <div
          className="relative h-full w-full overflow-hidden transition-colors duration-500 sm:rounded-[36px]"
          style={{ background: "var(--page)" }}
        >
          {/* faint top sheen */}
          <div
            aria-hidden
            className="pointer-events-none absolute inset-x-0 top-0 z-0 h-[46%]"
            style={{ background: "radial-gradient(70% 55% at 50% 0%, var(--sheen), transparent)" }}
          />

          <StatusBar connected={conn === "connected"} />

          <div className="relative z-[10] flex h-[calc(100%-44px)] flex-col">
            <Header onSubs={() => setDrawer("subs")} onSettings={() => setDrawer("settings")} />
            <IpWidget conn={conn} mode={mode} node={currentNode} onToast={showToast} />
            <div className="grid min-h-0 flex-1 place-items-center">
              <Globe state={conn} seconds={seconds} onToggle={toggleConnect} />
            </div>
            <ControlCard mode={mode} setMode={setMode} node={currentNode} onOpenNodes={() => setDrawer("nodes")} />
          </div>

          {/* gesture bar */}
          <div
            className="pointer-events-none absolute bottom-[7px] left-1/2 z-[35] h-[3.5px] w-28 -translate-x-1/2 rounded-full"
            style={{ background: "var(--bd3)" }}
          />

          {/* drawers */}
          <NodesDrawer
            open={drawer === "nodes"}
            onClose={() => setDrawer("none")}
            subs={subs}
            activeSubId={activeSub?.id ?? ""}
            onSwitchSub={switchSub}
            nodes={nodes}
            currentId={currentNode?.id ?? ""}
            onSelect={selectNode}
            onTest={testNode}
            onTestAll={testAll}
            onRefresh={() => refreshNodes()}
            lastUpdate={lastUpdate}
          />
          <SubscriptionDrawer
            open={drawer === "subs"}
            onClose={() => setDrawer("none")}
            subs={subs}
            onEnable={enableSub}
            onAdd={addSub}
            onEdit={editSub}
            onUpdate={updateSub}
            onDelete={deleteSub}
            updatingIds={updatingIds}
            toast={showToast}
          />
          <SettingsDrawer
            open={drawer === "settings"}
            onClose={() => setDrawer("none")}
            mode={mode}
            setMode={setMode}
            onOpenSubs={() => setDrawer("subs")}
            activeSub={activeSub}
            node={currentNode}
            toast={showToast}
          />

          {/* toast */}
          <AnimatePresence>
            {toast && (
              <motion.div
                key={toast.id}
                initial={{ opacity: 0, y: 14, scale: 0.94 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: 8, scale: 0.96 }}
                transition={{ type: "spring", damping: 26, stiffness: 380 }}
                className="pointer-events-none absolute bottom-[104px] left-1/2 z-[90] -translate-x-1/2 whitespace-nowrap rounded-full border bd2 px-[18px] py-2.5 text-[12.5px] backdrop-blur-md"
                style={{
                  background: "var(--toast)",
                  color: "var(--toast-fg)",
                  boxShadow: "var(--shadow-menu)",
                }}
              >
                {toast.msg}
              </motion.div>
            )}
          </AnimatePresence>

          <AnimatePresence>
            {showDisclaimer && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="absolute inset-0 z-[120] grid place-items-center bg-black/65 p-5 backdrop-blur-sm"
                onClick={() => setShowDisclaimer(false)}
              >
                <motion.section
                  initial={{ opacity: 0, y: 12, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: 8, scale: 0.98 }}
                  transition={{ type: "spring", damping: 28, stiffness: 360 }}
                  onClick={(event) => event.stopPropagation()}
                  aria-modal="true"
                  role="dialog"
                  aria-label="免责声明"
                  className="sf1 w-full max-w-[320px] rounded-2xl border bd2 p-5 shadow-2xl"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div>
                      <div className="t1 text-[15px] font-semibold">免责声明</div>
                      <div className="t5 mt-0.5 text-[11px]">Disclaimer</div>
                    </div>
                    <button
                      onClick={() => setShowDisclaimer(false)}
                      aria-label="关闭免责声明"
                      className="hov t3 grid h-7 w-7 place-items-center rounded-full"
                    >
                      <X size={15} />
                    </button>
                  </div>
                  <p className="t3 mt-4 text-[12px] leading-5">
                    此页面仅为交互式界面演示，不创建 VPN 连接、不处理真实订阅，也不提供节点、流量或账号。使用 FLsing 时，请自行确认配置来源、遵守适用法律及第三方服务条款，并对使用行为负责。
                  </p>
                  <a
                    href={`${PROJECT_URL}#免责声明与合规`}
                    target="_blank"
                    rel="noreferrer"
                    className="t2 hov-t mt-4 inline-flex items-center gap-1.5 rounded px-1 py-1 text-[12px] font-medium"
                  >
                    阅读完整免责声明
                    <ExternalLink size={13} />
                  </a>
                </motion.section>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}
