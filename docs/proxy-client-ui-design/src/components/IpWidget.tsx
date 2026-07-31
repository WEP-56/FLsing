import { AnimatePresence, motion } from "framer-motion";
import { Copy, MapPin, RefreshCw, ShieldCheck } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { fetchIpInfo, type IpInfo } from "../lib/ip";
import { ACCENT, EASE, type ConnState, type Mode, type NodeT } from "../lib/ui";

interface Props {
  conn: ConnState;
  mode: Mode;
  node: NodeT | null;
  onToast: (msg: string) => void;
}

export default function IpWidget({ conn, mode, node, onToast }: Props) {
  const [info, setInfo] = useState<IpInfo | null>(null);
  const [pending, setPending] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const reqRef = useRef(0);

  const load = useCallback(
    async (manual: boolean) => {
      const id = ++reqRef.current;
      if (manual) setRefreshing(true);
      const res = await fetchIpInfo(conn, mode, node);
      if (id !== reqRef.current) return;
      setInfo(res);
      setPending(false);
      setRefreshing(false);
    },
    [conn, mode, node?.id],
  );

  useEffect(() => {
    setPending(true);
    load(false);
  }, [load]);

  const busy = pending || conn === "connecting";
  const isExit = !busy && info?.exit;

  const copy = () => {
    if (!info) return;
    navigator.clipboard?.writeText(info.ip).catch(() => undefined);
    onToast("已复制 IP 地址");
  };

  const refresh = () => {
    if (refreshing || busy) return;
    setRefreshing(true);
    load(true);
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: -8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.45, delay: 0.08, ease: EASE }}
      className="sf1 mx-5 mb-1 flex h-9 items-center gap-2 rounded-full border bd1 pl-3 pr-1.5 backdrop-blur-md"
    >
      {/* status dot */}
      <span className="relative grid h-[7px] w-[7px] shrink-0 place-items-center">
        {isExit && (
          <motion.span
            className="absolute inset-0 rounded-full"
            style={{ background: ACCENT }}
            animate={{ scale: [1, 2.8], opacity: [0.5, 0] }}
            transition={{ duration: 1.8, repeat: Infinity, ease: "easeOut" }}
          />
        )}
        <span
          className="relative h-[7px] w-[7px] rounded-full transition-colors duration-500"
          style={{ background: busy ? "var(--t6)" : isExit ? ACCENT : "var(--t4)" }}
        />
      </span>

      <span className="t4 shrink-0">
        {isExit ? <ShieldCheck size={12} strokeWidth={2} /> : <MapPin size={12} strokeWidth={2} />}
      </span>
      <span className="t4 shrink-0 text-[11px]">{isExit ? "出口" : "本地"}</span>

      {/* ip */}
      <div className="min-w-0 flex-1">
        <AnimatePresence mode="wait">
          {busy ? (
            <motion.div
              key="sk"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.18 }}
              className="sf2 relative h-[9px] w-24 overflow-hidden rounded-full"
            >
              <motion.span
                className="sf3 absolute inset-y-0 w-8 rounded-full"
                animate={{ x: [-32, 104] }}
                transition={{ duration: 1, repeat: Infinity, ease: "easeInOut" }}
              />
            </motion.div>
          ) : (
            <motion.div
              key={info?.ip}
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -4 }}
              transition={{ duration: 0.24, ease: EASE }}
              className="flex items-baseline gap-2 overflow-hidden"
            >
              <span className="tnum t1 shrink-0 text-[12.5px] font-semibold tracking-[0.02em]">{info?.ip}</span>
              <span className="t5 truncate text-[10.5px]">{info?.region}</span>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* actions */}
      <button
        onClick={copy}
        disabled={busy}
        aria-label="复制 IP"
        className="hov hov-t t4 grid h-7 w-7 shrink-0 place-items-center rounded-full transition-all active:scale-90 disabled:opacity-30"
      >
        <Copy size={12.5} strokeWidth={1.9} />
      </button>
      <button
        onClick={refresh}
        disabled={busy}
        aria-label="重新检测"
        className="hov hov-t t4 grid h-7 w-7 shrink-0 place-items-center rounded-full transition-all active:scale-90 disabled:opacity-30"
      >
        <RefreshCw size={12.5} strokeWidth={1.9} className={refreshing ? "animate-spin" : ""} />
      </button>
    </motion.div>
  );
}
