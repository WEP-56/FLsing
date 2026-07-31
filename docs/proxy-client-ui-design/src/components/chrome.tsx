import { motion } from "framer-motion";
import { ChevronRight, Globe, KeyRound, Layers, Link2, Network, Settings, Signal, Wifi, Zap } from "lucide-react";
import { useEffect, useState } from "react";
import { latencyColor, pad2, EASE, type Mode, type NodeT } from "../lib/ui";

/* -------------------------------- status bar -------------------------------- */

export function StatusBar({ connected }: { connected: boolean }) {
  const [now, setNow] = useState(new Date());
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 20000);
    return () => window.clearInterval(id);
  }, []);
  return (
    <div className="t2 relative z-[30] flex h-11 items-center justify-between px-6 pt-1">
      <span className="tnum text-[12.5px] font-semibold tracking-wide">
        {pad2(now.getHours())}:{pad2(now.getMinutes())}
      </span>
      <div className="flex items-center gap-1.5">
        {connected && <KeyRound size={12} strokeWidth={2.2} />}
        <Signal size={13} strokeWidth={2.2} />
        <Wifi size={13} strokeWidth={2.2} />
        <span className="ml-0.5 flex h-[11px] w-[22px] items-center rounded-[3.5px] border bd3 p-[1.5px]">
          <span className="h-full w-[72%] rounded-[1.5px]" style={{ background: "currentColor" }} />
        </span>
      </div>
      {/* camera punch hole */}
      <span
        className="absolute left-1/2 top-3 h-3.5 w-3.5 -translate-x-1/2 rounded-full border bd1"
        style={{ background: "color-mix(in srgb, var(--page) 85%, var(--inv-bg))" }}
      />
    </div>
  );
}

/* ---------------------------------- header ---------------------------------- */

export function Header({ onSubs, onSettings }: { onSubs: () => void; onSettings: () => void }) {
  return (
    <header className="flex h-14 items-center justify-between px-5">
      <motion.span
        initial={{ opacity: 0, y: -6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: EASE }}
        className="t1 select-none text-[19px] font-bold tracking-tight"
      >
        FLsing
      </motion.span>
      <motion.div
        initial={{ opacity: 0, y: -6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.05, ease: EASE }}
        className="sf0 flex items-center gap-0.5 rounded-full border bd1 p-1"
      >
        <button
          onClick={onSubs}
          aria-label="订阅"
          className="hov t2 grid h-9 w-9 place-items-center rounded-full transition-colors active:scale-95"
        >
          <Layers size={17.5} strokeWidth={1.9} />
        </button>
        <button
          onClick={onSettings}
          aria-label="设置"
          className="hov t2 grid h-9 w-9 place-items-center rounded-full transition-colors active:scale-95"
        >
          <Settings size={17.5} strokeWidth={1.9} />
        </button>
      </motion.div>
    </header>
  );
}

/* ------------------------------- control card ------------------------------- */

const MODES: { key: Mode; label: string; icon: typeof Zap }[] = [
  { key: "rule", label: "规则", icon: Zap },
  { key: "global", label: "全局", icon: Globe },
  { key: "direct", label: "直连", icon: Link2 },
];

export function ControlCard({
  mode,
  setMode,
  node,
  onOpenNodes,
}: {
  mode: Mode;
  setMode: (m: Mode) => void;
  node: NodeT | null;
  onOpenNodes: () => void;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.55, delay: 0.1, ease: EASE }}
      className="sf1 mx-5 mb-7 rounded-[26px] border bd1 p-4 backdrop-blur-md"
    >
      <div className="t4 text-[12px]">模式</div>
      <div className="sf2 mt-2 flex rounded-full p-[4px]">
        {MODES.map((m) => {
          const active = mode === m.key;
          return (
            <button
              key={m.key}
              onClick={() => setMode(m.key)}
              className={`relative flex flex-1 items-center justify-center gap-1.5 rounded-full py-2 text-[13px] font-medium transition-colors ${
                active ? "" : "t3"
              }`}
              style={active ? { color: "var(--inv-fg)" } : undefined}
            >
              {active && (
                <motion.span
                  layoutId="modePill"
                  className="absolute inset-0 rounded-full"
                  style={{ background: "var(--inv-bg)" }}
                  transition={{ type: "spring", stiffness: 420, damping: 34 }}
                />
              )}
              <m.icon size={15} strokeWidth={2} className="relative z-10" />
              <span className="relative z-10">{m.label}</span>
            </button>
          );
        })}
      </div>

      <div className="my-3 h-px" style={{ background: "var(--bd1)" }} />

      <div className="t4 text-[12px]">当前节点</div>
      <button
        onClick={onOpenNodes}
        className="act mt-2 flex w-full items-center gap-3 rounded-2xl px-1 py-0.5 text-left transition-colors"
      >
        <span className="sf2 grid h-10 w-10 shrink-0 place-items-center rounded-full">
          <Network size={18} strokeWidth={1.8} className="t2" />
        </span>
        <span className="min-w-0 flex-1">
          <span className="t1 block truncate text-[14.5px] font-medium">
            {node ? `${node.country}｜${node.name}` : "暂无节点"}
          </span>
          {node && (
            <span className="t4 mt-0.5 block text-[12px]">
              延迟{" "}
              <span className="tnum font-medium" style={{ color: latencyColor(node.latency) }}>
                {node.latency == null ? "超时" : `${node.latency} ms`}
              </span>
            </span>
          )}
        </span>
        <ChevronRight size={19} className="t5 shrink-0" />
      </button>
    </motion.div>
  );
}
