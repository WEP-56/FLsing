import {
  Activity,
  BatteryCharging,
  Check,
  ChevronLeft,
  ChevronRight,
  Contrast,
  Eraser,
  FileText,
  Globe,
  Info,
  Layers,
  Link2,
  Monitor,
  Moon,
  Palette,
  Power,
  RefreshCw,
  RotateCcw,
  ShieldCheck,
  SlidersHorizontal,
  Sun,
  Timer,
  Wifi,
  X,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { AnimatePresence, motion } from "framer-motion";
import { useState, type ReactNode } from "react";
import { ACCENT, EASE, Sheet, Switch, type Mode, type NodeT, type Sub } from "../lib/ui";
import { useTheme, type ThemePref } from "../lib/theme";

interface Props {
  open: boolean;
  onClose: () => void;
  mode: Mode;
  setMode: (m: Mode) => void;
  onOpenSubs: () => void;
  activeSub: Sub | null;
  node: NodeT | null;
  toast: (msg: string) => void;
}

const CATS: { key: string; icon: LucideIcon; label: string }[] = [
  { key: "connect", icon: Link2, label: "连接" },
  { key: "proxy", icon: Globe, label: "代理方式" },
  { key: "subs", icon: Layers, label: "订阅与节点" },
  { key: "appearance", icon: Palette, label: "外观" },
  { key: "background", icon: Power, label: "后台与启动" },
  { key: "privacy", icon: ShieldCheck, label: "隐私与数据" },
  { key: "advanced", icon: SlidersHorizontal, label: "高级设置" },
  { key: "diagnostics", icon: Activity, label: "诊断" },
  { key: "about", icon: Info, label: "关于" },
];

const THEME_OPTS: { key: ThemePref; icon: LucideIcon; label: string; desc: string }[] = [
  { key: "light", icon: Sun, label: "浅色", desc: "暖调纸白，柔和不刺眼" },
  { key: "dark", icon: Moon, label: "深色", desc: "纯黑底色，更省电" },
  { key: "system", icon: Monitor, label: "跟随系统", desc: "随系统外观自动切换" },
];

export default function SettingsDrawer(p: Props) {
  const [page, setPage] = useState<string | null>(null);
  const { theme, pref, setPref } = useTheme();
  const [t, setT] = useState<Record<string, boolean>>({
    reconnect: true,
    switchOnFail: false,
    bypassLan: true,
    sysproxy: true,
    autoUpdateSub: true,
    highContrast: false,
    reduceMotion: false,
    autoStart: false,
    keepAlive: true,
    crashReport: false,
    ipv6: false,
  });
  const [diagRunning, setDiagRunning] = useState(false);
  const tg = (k: string) => () => setT((s) => ({ ...s, [k]: !s[k] }));

  const cat = CATS.find((c) => c.key === page);

  return (
    <Sheet open={p.open} onClose={p.onClose} full>
      <div className="relative flex flex-1 flex-col overflow-hidden">
        <AnimatePresence mode="popLayout" initial={false}>
          {page === null ? (
            <motion.div
              key="root"
              className="absolute inset-0 flex flex-col"
              initial={{ x: "-32%", opacity: 0.5 }}
              animate={{ x: 0, opacity: 1 }}
              exit={{ x: "-32%", opacity: 0 }}
              transition={{ duration: 0.32, ease: EASE }}
            >
              {/* header */}
              <div className="flex items-center justify-between px-5 pb-5 pt-3">
                <h2 className="t1 text-[24px] font-bold tracking-tight">设置</h2>
                <button
                  onClick={p.onClose}
                  aria-label="关闭设置"
                  className="sf2 hov t1 grid h-10 w-10 place-items-center rounded-full transition-all active:scale-95"
                >
                  <X size={18} strokeWidth={2} />
                </button>
              </div>
              {/* category list */}
              <div className="no-scrollbar flex-1 space-y-2.5 overflow-y-auto px-5 pb-10">
                {CATS.map((c, i) => (
                  <motion.button
                    key={c.key}
                    initial={{ opacity: 0, y: 16 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.04 + i * 0.035, duration: 0.34, ease: EASE }}
                    onClick={() => setPage(c.key)}
                    className="sf1 act flex w-full items-center gap-4 rounded-[20px] border bd1 p-4 text-left transition-colors"
                  >
                    <span className="sf2 grid h-11 w-11 shrink-0 place-items-center rounded-full">
                      <c.icon size={19} strokeWidth={1.7} className="t2" />
                    </span>
                    <span className="t1 flex-1 text-[15.5px] font-medium">{c.label}</span>
                    {c.key === "appearance" && (
                      <span className="t5 text-[11.5px]">
                        {pref === "system" ? "跟随系统" : theme === "dark" ? "深色" : "浅色"}
                      </span>
                    )}
                    <ChevronRight size={19} className="t5" />
                  </motion.button>
                ))}
                <div className="t6 pt-6 text-center text-[11px]">FLsing · 界面预览</div>
              </div>
            </motion.div>
          ) : (
            <motion.div
              key={page}
              className="absolute inset-0 flex flex-col"
              style={{ background: "var(--sheet)" }}
              initial={{ x: "100%" }}
              animate={{ x: 0 }}
              exit={{ x: "100%" }}
              transition={{ duration: 0.32, ease: EASE }}
            >
              {/* detail header */}
              <div className="flex items-center gap-2 px-4 pb-4 pt-3">
                <button
                  onClick={() => setPage(null)}
                  aria-label="返回"
                  className="sf2 hov t1 grid h-10 w-10 place-items-center rounded-full transition-all active:scale-95"
                >
                  <ChevronLeft size={19} strokeWidth={2} />
                </button>
                <h3 className="t1 text-[19px] font-bold tracking-tight">{cat?.label}</h3>
              </div>
              <div className="no-scrollbar flex-1 space-y-4 overflow-y-auto px-5 pb-10">{renderDetail()}</div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </Sheet>
  );

  /* ------------------------------ detail pages ------------------------------ */

  function Group({ children }: { children: ReactNode }) {
    return <div className="sf1 overflow-hidden rounded-[20px] border bd1">{children}</div>;
  }

  function Row({
    icon: Icon,
    title,
    desc,
    right,
    onClick,
    danger,
    last,
  }: {
    icon: LucideIcon;
    title: string;
    desc?: string;
    right?: ReactNode;
    onClick?: () => void;
    danger?: boolean;
    last?: boolean;
  }) {
    return (
      <button
        onClick={onClick}
        className={`act flex w-full items-center gap-3.5 px-4 py-3.5 text-left transition-colors ${
          last ? "" : "border-b bd1"
        }`}
      >
        <span className="sf2 grid h-9 w-9 shrink-0 place-items-center rounded-full">
          <Icon size={16} strokeWidth={1.8} className={danger ? "" : "t2"} style={danger ? { color: "var(--danger)" } : undefined} />
        </span>
        <span className="min-w-0 flex-1">
          <span
            className={`block text-[14px] ${danger ? "" : "t1"}`}
            style={danger ? { color: "var(--danger)" } : undefined}
          >
            {title}
          </span>
          {desc && <span className="t5 mt-0.5 block text-[11px]">{desc}</span>}
        </span>
        {right}
      </button>
    );
  }

  function RadioRow({
    icon,
    title,
    desc,
    active,
    onClick,
    last,
  }: {
    icon: LucideIcon;
    title: string;
    desc?: string;
    active: boolean;
    onClick: () => void;
    last?: boolean;
  }) {
    return (
      <Row
        icon={icon}
        title={title}
        desc={desc}
        onClick={onClick}
        last={last}
        right={
          <span
            className={`grid h-[22px] w-[22px] place-items-center rounded-full border ${active ? "" : "bd3"}`}
            style={active ? { background: "var(--inv-bg)", borderColor: "var(--inv-bg)" } : undefined}
          >
            {active && <Check size={13} strokeWidth={3.2} style={{ color: "var(--inv-fg)" }} />}
          </span>
        }
      />
    );
  }

  function Value({ children }: { children: ReactNode }) {
    return <span className="tnum t4 text-[12.5px]">{children}</span>;
  }

  function renderDetail() {
    switch (page) {
      case "connect":
        return (
          <Group>
            <Row icon={RefreshCw} title="自动重连" desc="断线后自动恢复连接" right={<Switch on={t.reconnect} onChange={tg("reconnect")} />} />
            <Row icon={Zap} title="失败自动切换节点" desc="当前节点不可用时切换到最快节点" right={<Switch on={t.switchOnFail} onChange={tg("switchOnFail")} />} />
            <Row icon={Wifi} title="绕过局域网" desc="本地网络直接访问，不走代理" right={<Switch on={t.bypassLan} onChange={tg("bypassLan")} />} />
            <Row icon={Timer} title="连接超时" right={<Value>10 秒</Value>} onClick={() => p.toast("界面预览：选项未开放")} last />
          </Group>
        );
      case "proxy":
        return (
          <>
            <Group>
              <RadioRow icon={Zap} title="规则模式" active={p.mode === "rule"} onClick={() => p.setMode("rule")} />
              <RadioRow icon={Globe} title="全局模式" active={p.mode === "global"} onClick={() => p.setMode("global")} />
              <RadioRow icon={Link2} title="直连模式" active={p.mode === "direct"} onClick={() => p.setMode("direct")} last />
            </Group>
            <Group>
              <Row icon={Layers} title="系统代理" desc="将代理配置写入系统网络设置" right={<Switch on={t.sysproxy} onChange={tg("sysproxy")} />} last />
            </Group>
          </>
        );
      case "subs":
        return (
          <Group>
            <Row
              icon={Layers}
              title="管理订阅"
              desc={p.activeSub ? `当前：${p.activeSub.name}` : "尚未添加订阅"}
              right={<ChevronRight size={17} className="t5" />}
              onClick={() => {
                p.onClose();
                p.onOpenSubs();
              }}
            />
            <Row icon={RefreshCw} title="自动更新订阅" right={<Switch on={t.autoUpdateSub} onChange={tg("autoUpdateSub")} />} />
            <Row icon={Timer} title="更新间隔" right={<Value>24 小时</Value>} onClick={() => p.toast("界面预览：选项未开放")} last />
          </Group>
        );
      case "appearance":
        return (
          <>
            {/* live theme preview */}
            <motion.div
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, ease: EASE }}
              className="flex gap-3"
            >
              {(["light", "dark"] as const).map((tm) => {
                const on = theme === tm;
                return (
                  <button
                    key={tm}
                    onClick={() => setPref(tm)}
                    className={`flex-1 overflow-hidden rounded-[18px] border p-3 transition-all active:scale-[0.98] ${on ? "bd3" : "bd1"}`}
                    style={{ background: tm === "dark" ? "#0B0B0B" : "#F4F3EF" }}
                  >
                    <div
                      className="mb-2.5 grid h-14 place-items-center rounded-xl"
                      style={{ background: tm === "dark" ? "#000" : "#EAE8E3" }}
                    >
                      <span
                        className="h-7 w-7 rounded-full border"
                        style={{
                          borderColor: tm === "dark" ? "rgba(255,255,255,0.25)" : "rgba(26,25,21,0.25)",
                          background: tm === "dark" ? "#1a1a1a" : "#fff",
                        }}
                      />
                    </div>
                    <div className="flex items-center justify-between">
                      <span
                        className="text-[12.5px] font-medium"
                        style={{ color: tm === "dark" ? "rgba(255,255,255,0.9)" : "rgba(26,25,21,0.9)" }}
                      >
                        {tm === "dark" ? "深色" : "浅色"}
                      </span>
                      {on && (
                        <span className="grid h-4 w-4 place-items-center rounded-full" style={{ background: ACCENT }}>
                          <Check size={10} strokeWidth={3.4} color="#fff" />
                        </span>
                      )}
                    </div>
                  </button>
                );
              })}
            </motion.div>

            <Group>
              {THEME_OPTS.map((o, i) => (
                <RadioRow
                  key={o.key}
                  icon={o.icon}
                  title={o.label}
                  desc={o.desc}
                  active={pref === o.key}
                  onClick={() => setPref(o.key)}
                  last={i === THEME_OPTS.length - 1}
                />
              ))}
            </Group>

            <Group>
              <Row icon={Contrast} title="提高对比度" desc="增强文字与描边的可读性" right={<Switch on={t.highContrast} onChange={tg("highContrast")} />} />
              <Row icon={Activity} title="减少动态效果" right={<Switch on={t.reduceMotion} onChange={tg("reduceMotion")} />} last />
            </Group>
          </>
        );
      case "background":
        return (
          <Group>
            <Row icon={Power} title="开机自启" desc="设备启动后自动运行" right={<Switch on={t.autoStart} onChange={tg("autoStart")} />} />
            <Row icon={Activity} title="后台保持连接" desc="锁屏后保持代理在线" right={<Switch on={t.keepAlive} onChange={tg("keepAlive")} />} />
            <Row icon={BatteryCharging} title="忽略电池优化" desc="避免系统清理后台服务" right={<Value>已允许</Value>} onClick={() => p.toast("界面预览：选项未开放")} last />
          </Group>
        );
      case "privacy":
        return (
          <Group>
            <Row icon={Activity} title="崩溃分析" desc="匿名上报以帮助改进" right={<Switch on={t.crashReport} onChange={tg("crashReport")} />} />
            <Row icon={Eraser} title="清除使用数据" onClick={() => p.toast("使用数据已清除")} right={<ChevronRight size={17} className="t5" />} />
            <Row icon={FileText} title="导出运行日志" onClick={() => p.toast("日志已导出")} right={<ChevronRight size={17} className="t5" />} last />
          </Group>
        );
      case "advanced":
        return (
          <Group>
            <Row icon={SlidersHorizontal} title="混合端口" right={<Value>7890</Value>} onClick={() => p.toast("界面预览：选项未开放")} />
            <Row icon={Globe} title="DNS 模式" right={<Value>Fake-IP</Value>} onClick={() => p.toast("界面预览：选项未开放")} />
            <Row icon={Wifi} title="IPv6" right={<Switch on={t.ipv6} onChange={tg("ipv6")} />} />
            <Row icon={RotateCcw} title="重置高级设置" danger onClick={() => p.toast("已重置为默认值")} last />
          </Group>
        );
      case "diagnostics":
        return (
          <>
            <Group>
              <Row icon={Activity} title="网络延迟" right={<Value>{p.node?.latency != null ? `${p.node.latency} ms` : "—"}</Value>} />
              <Row
                icon={Globe}
                title="DNS 解析"
                right={
                  <span className="text-[12.5px]" style={{ color: ACCENT }}>
                    正常
                  </span>
                }
                last
              />
            </Group>
            <Group>
              <Row
                icon={RefreshCw}
                title={diagRunning ? "正在诊断…" : "运行诊断"}
                desc="检查连接、DNS 与节点可用性"
                onClick={() => {
                  if (diagRunning) return;
                  setDiagRunning(true);
                  window.setTimeout(() => {
                    setDiagRunning(false);
                    p.toast("诊断完成：一切正常");
                  }, 1500);
                }}
              />
              <Row icon={FileText} title="导出诊断报告" onClick={() => p.toast("诊断报告已导出")} last />
            </Group>
          </>
        );
      case "about":
        return (
          <>
            <motion.div
              initial={{ opacity: 0, y: 14 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, ease: EASE }}
              className="flex flex-col items-center gap-2.5 py-6"
            >
              <span className="sf2 grid h-16 w-16 place-items-center rounded-[22px] border bd2">
                <Zap size={26} strokeWidth={1.8} className="t1" />
              </span>
              <span className="t1 text-[17px] font-bold">FLsing</span>
              <span className="t5 text-[11.5px]">版本 1.0.0（Preview）</span>
            </motion.div>
            <Group>
              <Row icon={RefreshCw} title="检查更新" onClick={() => p.toast("当前已是最新版本")} right={<ChevronRight size={17} className="t5" />} />
              <Row icon={FileText} title="开源许可" onClick={() => p.toast("界面预览：页面未开放")} right={<ChevronRight size={17} className="t5" />} />
              <Row icon={Info} title="用户协议与隐私政策" onClick={() => p.toast("界面预览：页面未开放")} right={<ChevronRight size={17} className="t5" />} last />
            </Group>
          </>
        );
      default:
        return null;
    }
  }
}
