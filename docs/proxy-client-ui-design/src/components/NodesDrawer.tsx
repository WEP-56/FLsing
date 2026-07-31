import { Check, ChevronDown, Gauge, Info, Layers, LayoutGrid, List, Loader2, MoreVertical, RefreshCw, Search } from "lucide-react";
import { motion } from "framer-motion";
import { useState } from "react";
import {
  CountryChip,
  Dialog,
  EASE,
  latencyColor,
  latencyLevel,
  MiniBars,
  PopMenu,
  Sheet,
  type NodeT,
  type Sub,
} from "../lib/ui";

interface Props {
  open: boolean;
  onClose: () => void;
  subs: Sub[];
  activeSubId: string;
  onSwitchSub: (id: string) => void;
  nodes: NodeT[];
  currentId: string;
  onSelect: (id: string) => void;
  onTest: (id: string) => void;
  onTestAll: () => void;
  onRefresh: () => void;
  lastUpdate: string;
}

export default function NodesDrawer(p: Props) {
  const [q, setQ] = useState("");
  const [grid, setGrid] = useState(false);
  const [menuFor, setMenuFor] = useState<string | null>(null);
  const [subMenu, setSubMenu] = useState(false);
  const [info, setInfo] = useState<NodeT | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const testingAll = p.nodes.some((n) => n.testing);
  const activeSub = p.subs.find((s) => s.id === p.activeSubId);
  const filtered = p.nodes.filter(
    (n) => !q.trim() || `${n.country}${n.name}${n.code}`.toLowerCase().includes(q.trim().toLowerCase()),
  );

  return (
    <Sheet open={p.open} onClose={p.onClose}>
      {/* header */}
      <div className="flex items-start justify-between px-5 pb-3 pt-2">
        <div>
          <h2 className="t1 text-[22px] font-bold tracking-tight">节点管理</h2>
          <div className="relative mt-0.5 inline-block">
            <button
              onClick={() => setSubMenu(true)}
              className="t4 flex items-center gap-1 rounded-full py-1 pr-1 text-[12.5px] active:opacity-70"
            >
              当前订阅：<span className="t2 font-medium">{activeSub?.name ?? "—"}</span>
              <ChevronDown size={13} />
            </button>
            <PopMenu
              open={subMenu}
              onClose={() => setSubMenu(false)}
              className="left-0 top-full mt-1.5"
              origin="top left"
              items={p.subs.map((s) => ({
                icon: s.id === p.activeSubId ? Check : Layers,
                label: s.name,
                onClick: () => p.onSwitchSub(s.id),
              }))}
            />
          </div>
        </div>
        <div className="flex gap-2 pt-1">
          <button
            onClick={p.onTestAll}
            disabled={testingAll}
            aria-label="全部测速"
            className="sf1 t2 flex h-12 w-14 flex-col items-center justify-center gap-[3px] rounded-xl border bd1 transition-all active:scale-95 disabled:opacity-60"
          >
            {testingAll ? <Loader2 size={16} className="animate-spin" /> : <Gauge size={16} strokeWidth={1.9} />}
            <span className="t4 text-[9.5px]">测速</span>
          </button>
          <button
            onClick={() => setGrid((g) => !g)}
            aria-label="切换视图"
            className="sf1 t2 flex h-12 w-14 flex-col items-center justify-center gap-[3px] rounded-xl border bd1 transition-all active:scale-95"
          >
            {grid ? <List size={16} strokeWidth={1.9} /> : <LayoutGrid size={16} strokeWidth={1.9} />}
            <span className="t4 text-[9.5px]">视图</span>
          </button>
        </div>
      </div>

      {/* search */}
      <div className="px-5 pb-3">
        <div className="relative">
          <Search size={15} className="t5 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="搜索节点"
            className="sf1 t1 h-10 w-full rounded-full border bd1 pl-10 pr-4 text-[13.5px] outline-none placeholder:opacity-45 focus:border-[var(--bd3)]"
          />
        </div>
      </div>

      {/* list */}
      <div
        className={`no-scrollbar flex-1 overflow-y-auto px-5 pb-2 ${grid ? "grid content-start gap-2" : "space-y-2"}`}
        style={grid ? { gridTemplateColumns: "1fr 1fr" } : undefined}
      >
        {filtered.map((n, i) => {
          const selected = n.id === p.currentId;
          if (grid) {
            return (
              <motion.button
                key={n.id}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.03 + i * 0.03, duration: 0.3, ease: EASE }}
                onClick={() => p.onSelect(n.id)}
                className={`flex flex-col items-start gap-2.5 rounded-2xl border p-3.5 text-left transition-colors ${
                  selected ? "sf2 bd3" : "sf1 bd1"
                }`}
              >
                <div className="flex w-full items-center justify-between">
                  <CountryChip code={n.code} />
                  {selected && (
                    <span
                      className="grid h-5 w-5 place-items-center rounded-full"
                      style={{ background: "var(--inv-bg)" }}
                    >
                      <Check size={12} strokeWidth={3} style={{ color: "var(--inv-fg)" }} />
                    </span>
                  )}
                </div>
                <div className="min-w-0">
                  <div className="t1 truncate text-[13.5px] font-medium">{n.name}</div>
                  <div className="t5 mt-0.5 text-[10.5px]">{n.country}</div>
                </div>
                <div className="flex w-full items-center justify-between">
                  <span className="tnum text-[12.5px] font-medium" style={{ color: latencyColor(n.latency) }}>
                    {n.testing ? "…" : n.latency == null ? "超时" : `${n.latency} ms`}
                  </span>
                  <MiniBars level={latencyLevel(n.latency)} size={11} />
                </div>
              </motion.button>
            );
          }
          return (
            <motion.div
              key={n.id}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.03 + i * 0.035, duration: 0.3, ease: EASE }}
              className={`relative flex items-center gap-3 rounded-2xl border p-3 transition-colors ${
                selected ? "sf2 bd2" : "sf1 bd1"
              }`}
            >
              {selected && (
                <span
                  className="absolute left-0 top-1/2 h-8 w-[3px] -translate-y-1/2 rounded-r-full"
                  style={{ background: "var(--inv-bg)" }}
                />
              )}
              <button
                onClick={() => p.onSelect(n.id)}
                aria-label="选择节点"
                className={`grid h-[22px] w-[22px] shrink-0 place-items-center rounded-full border transition-all ${
                  selected ? "" : "bd3"
                }`}
                style={selected ? { background: "var(--inv-bg)", borderColor: "var(--inv-bg)" } : undefined}
              >
                {selected && <Check size={13} strokeWidth={3.2} style={{ color: "var(--inv-fg)" }} />}
              </button>
              <CountryChip code={n.code} />
              <button onClick={() => p.onSelect(n.id)} className="min-w-0 flex-1 text-left">
                <div className="t1 truncate text-[14.5px] font-medium">
                  {n.country}｜{n.name}
                </div>
                <div className="t5 mt-0.5 text-[10.5px] tracking-wide">
                  {n.proto}
                  <span className="t6 mx-1.5">·</span>
                  {n.transport}
                </div>
              </button>
              <div className="flex w-[60px] flex-col items-end gap-1">
                <span className="tnum text-[13px] font-medium" style={{ color: latencyColor(n.latency) }}>
                  {n.latency == null ? "超时" : `${n.latency} ms`}
                </span>
                <MiniBars level={latencyLevel(n.latency)} size={11} />
              </div>
              <button
                onClick={() => p.onTest(n.id)}
                aria-label="单节点测速"
                className="sf2 hov t3 grid h-9 w-9 shrink-0 place-items-center rounded-full transition-all active:scale-95"
              >
                {n.testing ? <Loader2 size={15} className="animate-spin" /> : <Gauge size={15} strokeWidth={1.9} />}
              </button>
              <div className="relative shrink-0">
                <button
                  onClick={() => setMenuFor(n.id)}
                  aria-label="更多"
                  className="t4 grid h-8 w-6 place-items-center"
                >
                  <MoreVertical size={16} />
                </button>
                <PopMenu
                  open={menuFor === n.id}
                  onClose={() => setMenuFor(null)}
                  items={[
                    { icon: Check, label: "设为当前", onClick: () => p.onSelect(n.id) },
                    { icon: Gauge, label: "测速", onClick: () => p.onTest(n.id) },
                    { icon: Info, label: "节点信息", onClick: () => setInfo(n) },
                  ]}
                />
              </div>
            </motion.div>
          );
        })}
        {filtered.length === 0 && (
          <div className="t5 grid place-items-center py-16 text-[13px]">
            {p.nodes.length === 0 ? "暂无节点，请先添加订阅" : "未找到匹配的节点"}
          </div>
        )}
      </div>

      {/* footer */}
      <div className="t5 flex items-center justify-between px-5 pb-7 pt-2.5 text-[11.5px]">
        <span className="flex items-center gap-1.5">
          <Info size={12} />
          上次更新：{p.lastUpdate}
        </span>
        <button
          onClick={() => {
            setRefreshing(true);
            p.onRefresh();
            window.setTimeout(() => setRefreshing(false), 900);
          }}
          className="t3 flex items-center gap-1.5 font-medium transition-colors"
        >
          <RefreshCw size={12.5} className={refreshing ? "animate-spin" : ""} />
          更新节点
        </button>
      </div>

      {/* node info dialog */}
      <Dialog
        open={!!info}
        onClose={() => setInfo(null)}
        title={info?.name}
        actions={[{ label: "关闭", primary: true, onClick: () => setInfo(null) }]}
      >
        {info && (
          <div className="mt-2 space-y-2.5 text-[13px]">
            {[
              ["地区", info.country],
              ["协议", info.proto],
              ["传输", info.transport],
              ["延迟", info.latency == null ? "超时" : `${info.latency} ms`],
              ["来源", activeSub?.name ?? "—"],
            ].map(([k, v]) => (
              <div
                key={k}
                className="flex items-center justify-between border-b bd1 pb-2.5 last:border-0 last:pb-0"
              >
                <span className="t4">{k}</span>
                <span className="tnum t1">{v}</span>
              </div>
            ))}
          </div>
        )}
      </Dialog>
    </Sheet>
  );
}
