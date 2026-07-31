import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type ThemeName = "dark" | "light";
export type ThemePref = ThemeName | "system";

interface Ctx {
  theme: ThemeName;
  pref: ThemePref;
  setPref: (p: ThemePref) => void;
  toggle: () => void;
}

const ThemeCtx = createContext<Ctx>({
  theme: "dark",
  pref: "dark",
  setPref: () => undefined,
  toggle: () => undefined,
});

const systemTheme = (): ThemeName =>
  typeof window !== "undefined" && window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [pref, setPref] = useState<ThemePref>("dark");
  const [sys, setSys] = useState<ThemeName>(systemTheme);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme: light)");
    const on = () => setSys(mq.matches ? "light" : "dark");
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, []);

  const theme: ThemeName = pref === "system" ? sys : pref;

  useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  const toggle = useCallback(() => setPref(theme === "dark" ? "light" : "dark"), [theme]);

  const value = useMemo(() => ({ theme, pref, setPref, toggle }), [theme, pref, toggle]);
  return <ThemeCtx.Provider value={value}>{children}</ThemeCtx.Provider>;
}

export const useTheme = () => useContext(ThemeCtx);
