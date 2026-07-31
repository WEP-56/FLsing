import { AnimatePresence, motion } from "framer-motion";
import type { LucideIcon } from "lucide-react";
import { useRef, type ReactNode } from "react";
import { useTheme } from "./theme";

/* ---------------------------------- tokens ---------------------------------- */

export const EASE: [number, number, number, number] = [0.32, 0.72, 0, 1] as [
  number,
  number,
  number,
  number,
];

/* CSS variables so every colour follows the active theme automatically. */
export const ACCENT = "var(--accent)";
export const WARN = "var(--warn)";
export const DANGER = "var(--danger)";

/* ---------------------------------- types ---------------------------------- */

export type ConnState = "idle" | "connecting" | "connected";
export type Mode = "rule" | "global" | "direct";

export interface Sub {
  id: string;
  name: string;
  url: string;
  updated: string;
  active: boolean;
}

export interface NodeT {
  id: string;
  country: string;
  name: string;
  code: string;
  proto: string;
  transport: string;
  latency: number | null;
  testing?: boolean;
}

/* ---------------------------------- helpers ---------------------------------- */

export const latencyColor = (l: number | null | undefined): string =>
  l == null ? "var(--t5)" : l < 100 ? ACCENT : l < 150 ? WARN : DANGER;

export const latencyLevel = (l: number | null | undefined): number =>
  l == null ? 0 : l < 100 ? 4 : l < 150 ? 3 : 2;

export const pad2 = (n: number) => String(n).padStart(2, "0");

export const fmtNow = () => {
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
};

export const fmtHMS = (s: number) => {
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return `${pad2(h)}:${pad2(m)}:${pad2(sec)}`;
};

export const uid = () => Math.random().toString(36).slice(2, 9);

/* ---------------------------------- hooks ---------------------------------- */

export function useLongPress(cb: () => void, ms = 480) {
  const t = useRef<number | undefined>(undefined);
  const fired = useRef(false);
  const start = () => {
    fired.current = false;
    t.current = window.setTimeout(() => {
      fired.current = true;
      cb();
    }, ms);
  };
  const clear = () => window.clearTimeout(t.current);
  const onClickCapture = (e: React.SyntheticEvent) => {
    if (fired.current) {
      e.stopPropagation();
      e.preventDefault();
      fired.current = false;
    }
  };
  return {
    onTouchStart: start,
    onTouchEnd: clear,
    onTouchMove: clear,
    onMouseDown: start,
    onMouseUp: clear,
    onMouseLeave: clear,
    onClickCapture,
    onContextMenu: (e: React.MouseEvent) => {
      e.preventDefault();
      clear();
      cb();
    },
  };
}

/* ---------------------------------- atoms ---------------------------------- */

export function MiniBars({ level, size = 13 }: { level: number; size?: number }) {
  const hs = [0.36, 0.58, 0.79, 1];
  const color = level === 4 ? ACCENT : level === 3 ? WARN : level > 0 ? DANGER : "var(--sf3)";
  return (
    <span className="inline-flex items-end gap-[2.5px]" style={{ height: size }}>
      {hs.map((h, i) => (
        <span
          key={i}
          className="w-[3px] rounded-full"
          style={{ height: size * h, background: i < level ? color : "var(--sf3)" }}
        />
      ))}
    </span>
  );
}

export function CountryChip({ code }: { code: string }) {
  return (
    <span className="sf2 t2 grid h-9 w-9 shrink-0 select-none place-items-center rounded-[10px] border bd1 text-[10.5px] font-bold tracking-[0.14em]">
      {code}
    </span>
  );
}

export function Switch({ on, onChange }: { on: boolean; onChange: (v: boolean) => void }) {
  const { theme } = useTheme();
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      onClick={(e) => {
        e.stopPropagation();
        onChange(!on);
      }}
      className={`relative h-[26px] w-[46px] shrink-0 rounded-full transition-colors duration-300 ${on ? "" : "sf3"}`}
      style={on ? { background: "var(--inv-bg)" } : undefined}
    >
      <motion.span
        className="absolute left-0 top-[3px] h-5 w-5 rounded-full"
        animate={{
          x: on ? 23 : 3,
          backgroundColor: on
            ? theme === "dark"
              ? "#000000"
              : "#F5F4F0"
            : theme === "dark"
              ? "#8d8d8d"
              : "#ffffff",
        }}
        transition={{ type: "spring", stiffness: 520, damping: 32 }}
      />
    </button>
  );
}

export function Field({ label, ...rest }: React.InputHTMLAttributes<HTMLInputElement> & { label?: string }) {
  return (
    <label className="block">
      {label && <span className="t4 mb-1.5 block text-[11.5px]">{label}</span>}
      <input
        {...rest}
        className="sf1 t1 w-full rounded-xl border bd2 px-3.5 py-2.5 text-[13.5px] outline-none transition-colors placeholder:opacity-45 focus:border-[var(--bd3)]"
      />
    </label>
  );
}

/* ---------------------------------- overlays ---------------------------------- */

export type MenuItem = { icon: LucideIcon; label: string; danger?: boolean; onClick: () => void };

export function PopMenu({
  open,
  onClose,
  items,
  className = "right-0 top-full mt-2",
  origin = "top right",
}: {
  open: boolean;
  onClose: () => void;
  items: MenuItem[];
  className?: string;
  origin?: string;
}) {
  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            key="pm-bd"
            className="fixed inset-0 z-[60]"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            onContextMenu={(e) => {
              e.preventDefault();
              onClose();
            }}
          />
          <motion.div
            key="pm-menu"
            initial={{ opacity: 0, scale: 0.9, y: -6 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.94, y: -4 }}
            transition={{ duration: 0.18, ease: EASE }}
            style={{
              transformOrigin: origin,
              background: "var(--menu)",
              boxShadow: "var(--shadow-menu)",
            }}
            className={`absolute z-[70] min-w-[188px] overflow-hidden rounded-2xl border bd2 p-1.5 backdrop-blur-xl ${className}`}
          >
            {items.map((it, i) => (
              <button
                key={i}
                onClick={() => {
                  onClose();
                  it.onClick();
                }}
                className={`hov flex w-full items-center gap-3 rounded-xl px-3.5 py-2.5 text-left text-[13.5px] transition-colors ${
                  it.danger ? "" : "t1"
                }`}
                style={it.danger ? { color: DANGER } : undefined}
              >
                <it.icon size={16} strokeWidth={1.8} className={it.danger ? "" : "t3"} />
                {it.label}
              </button>
            ))}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}

export function Dialog({
  open,
  onClose,
  title,
  children,
  actions,
}: {
  open: boolean;
  onClose: () => void;
  title?: string;
  children?: ReactNode;
  actions?: { label: string; danger?: boolean; primary?: boolean; onClick: () => void }[];
}) {
  return (
    <AnimatePresence>
      {open && (
        <div key="dlg" className="absolute inset-0 z-[80]">
          <motion.div
            className="absolute inset-0 backdrop-blur-[3px]"
            style={{ background: "color-mix(in srgb, var(--page) 62%, transparent)" }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.22 }}
            onClick={onClose}
          />
          <div className="pointer-events-none absolute inset-0 grid place-items-center p-7">
            <motion.div
              className="pointer-events-auto w-full max-w-[308px] rounded-[26px] border bd2 p-5"
              style={{ background: "var(--dialog)", boxShadow: "var(--shadow-dialog)" }}
              initial={{ opacity: 0, scale: 0.9, y: 14 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.94, y: 8 }}
              transition={{ type: "spring", damping: 26, stiffness: 340 }}
            >
              {title && <div className="t1 mb-1 text-[16px] font-semibold">{title}</div>}
              {children}
              {actions && (
                <div className="mt-5 flex gap-2.5">
                  {actions.map((a, i) => (
                    <button
                      key={i}
                      onClick={a.onClick}
                      className={`flex-1 rounded-full py-2.5 text-[13.5px] font-medium transition-all active:scale-[0.96] ${
                        a.primary ? "inv" : a.danger ? "" : "sf2 t1"
                      }`}
                      style={a.danger ? { background: "var(--danger-soft)", color: DANGER } : undefined}
                    >
                      {a.label}
                    </button>
                  ))}
                </div>
              )}
            </motion.div>
          </div>
        </div>
      )}
    </AnimatePresence>
  );
}

export function Sheet({
  open,
  onClose,
  full = false,
  children,
}: {
  open: boolean;
  onClose: () => void;
  full?: boolean;
  children: ReactNode;
}) {
  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            key="sheet-bd"
            className="absolute inset-0 z-[40] backdrop-blur-[2px]"
            style={{ background: "color-mix(in srgb, var(--page) 58%, transparent)" }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.26 }}
            onClick={onClose}
          />
          <motion.div
            key="sheet"
            className={`absolute inset-x-0 bottom-0 z-[50] flex flex-col overflow-hidden ${
              full ? "top-0" : "h-[84%] rounded-t-[30px] border-t bd2"
            }`}
            style={{ background: "var(--sheet)" }}
            initial={{ y: "103%" }}
            animate={{ y: 0 }}
            exit={{ y: "103%" }}
            transition={{ type: "spring", damping: 31, stiffness: 270 }}
          >
            <div className="mx-auto mt-2.5 h-[5px] w-10 shrink-0 rounded-full" style={{ background: "var(--bd3)" }} />
            {children}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
