import { useEffect, useRef } from "react";
import { Loader2 } from "lucide-react";
import { ACCENT, fmtHMS, MiniBars, type ConnState } from "../lib/ui";
import { useTheme, type ThemeName } from "../lib/theme";
// @ts-expect-error vite asset import
import mapUrl from "../assets/earth-map.jpg";

/* Palette per theme — canvas needs literal colours. */
const PALETTE: Record<
  ThemeName,
  {
    dot: string;
    core: [string, string, string];
    rim: [string, string];
    line: string;
    spark: string;
    glow: string;
  }
> = {
  dark: {
    dot: "232,232,232",
    core: ["rgba(28,28,28,", "rgba(12,12,12,", "rgba(22,22,22,"],
    rim: ["255,255,255", "255,255,255"],
    line: "255,255,255",
    spark: "255,255,255",
    glow: "255,255,255",
  },
  light: {
    dot: "44,42,36",
    core: ["rgba(255,255,255,", "rgba(232,230,223,", "rgba(214,211,202,"],
    rim: ["26,25,21", "26,25,21"],
    line: "26,25,21",
    spark: "38,36,30",
    glow: "26,25,21",
  },
};

function fallbackSphere(): Float32Array {
  const N = 1500;
  const pts: number[] = [];
  const ga = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < N; i++) {
    const y = 1 - (i / (N - 1)) * 2;
    const r = Math.sqrt(1 - y * y);
    const th = ga * i;
    pts.push(Math.cos(th) * r, y, Math.sin(th) * r);
  }
  return new Float32Array(pts);
}

interface Props {
  state: ConnState;
  seconds: number;
  onToggle: () => void;
}

export default function Globe({ state, seconds, onToggle }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stRef = useRef(state);
  stRef.current = state;
  const ptsRef = useRef<Float32Array | null>(null);
  const { theme } = useTheme();
  const themeRef = useRef(theme);
  themeRef.current = theme;

  /* Sample landmass dots from the equirectangular map image. */
  useEffect(() => {
    let dead = false;
    const img = new Image();
    img.src = mapUrl as string;
    img.onload = () => {
      if (dead) return;
      try {
        const W = 220;
        const H = 110;
        const oc = document.createElement("canvas");
        oc.width = W;
        oc.height = H;
        const cx = oc.getContext("2d");
        if (!cx) throw new Error();
        cx.imageSmoothingEnabled = true;
        cx.drawImage(img, 0, 0, W, H);
        const d = cx.getImageData(0, 0, W, H).data;
        const pts: number[] = [];
        for (let y = 0; y < H; y++) {
          for (let x = 0; x < W; x++) {
            const i = (y * W + x) * 4;
            const lum = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
            if (lum > 110) {
              const lat = (y / H - 0.5) * Math.PI;
              const lon = (x / W) * Math.PI * 2;
              pts.push(Math.cos(lat) * Math.cos(lon), Math.sin(lat), Math.cos(lat) * Math.sin(lon));
            }
          }
        }
        ptsRef.current = pts.length > 800 ? new Float32Array(pts) : fallbackSphere();
      } catch {
        ptsRef.current = fallbackSphere();
      }
    };
    img.onerror = () => {
      ptsRef.current = fallbackSphere();
    };
    return () => {
      dead = true;
    };
  }, []);

  /* Render loop */
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let raf = 0;
    let spin = 0.6;
    let sat = 1.2;
    let last = performance.now();
    let haloTimer = 0;
    const halos: number[] = [];
    const anim = { speed: 0.05, alpha: 0.42, ring: 0.06, halo: 0, glow: 0 };

    const dpr = () => Math.min(window.devicePixelRatio || 1, 2);
    const resize = () => {
      const d = dpr();
      canvas.width = canvas.clientWidth * d;
      canvas.height = canvas.clientHeight * d;
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    const TILT = -0.42;
    const cosT = Math.cos(TILT);
    const sinT = Math.sin(TILT);

    const frame = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      const s = stRef.current;
      const P = PALETTE[themeRef.current];
      const lightMode = themeRef.current === "light";

      const tgt =
        s === "connected"
          ? { speed: 0.22, alpha: 1, ring: 0.9, halo: 0, glow: 1 }
          : s === "connecting"
            ? { speed: 1.4, alpha: 0.9, ring: 0.6, halo: 1, glow: 0.45 }
            : { speed: 0.05, alpha: 0.42, ring: 0.06, halo: 0, glow: 0 };
      const k = 1 - Math.pow(0.004, dt);
      anim.speed += (tgt.speed - anim.speed) * k;
      anim.alpha += (tgt.alpha - anim.alpha) * k;
      anim.ring += (tgt.ring - anim.ring) * k;
      anim.halo += (tgt.halo - anim.halo) * k;
      anim.glow += (tgt.glow - anim.glow) * k;
      spin += anim.speed * dt;
      sat += (0.35 + anim.speed * 0.8) * dt;

      /* light mode needs a slightly firmer floor so the globe never washes out */
      const alpha = lightMode ? 0.55 + anim.alpha * 0.45 : anim.alpha;

      const W = canvas.width;
      const H = canvas.height;
      const d = dpr();
      ctx.clearRect(0, 0, W, H);
      const cxp = W / 2;
      const cyp = H / 2;
      const R = Math.min(W, H) * 0.335;
      const ringR = R * 1.3;

      /* expanding halos (connecting) */
      if (anim.halo > 0.25) {
        haloTimer += dt;
        if (haloTimer > 0.85) {
          halos.push(0);
          haloTimer = 0;
        }
      }
      for (let i = halos.length - 1; i >= 0; i--) {
        halos[i] += dt / 1.5;
        const t = halos[i];
        if (t >= 1) {
          halos.splice(i, 1);
          continue;
        }
        ctx.beginPath();
        ctx.arc(cxp, cyp, R * (1.05 + 0.62 * t), 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(${P.line},${((1 - t) * (lightMode ? 0.3 : 0.22) * anim.halo).toFixed(3)})`;
        ctx.lineWidth = 1.2 * d;
        ctx.stroke();
      }

      /* soft aura */
      if (anim.glow > 0.02) {
        const ga = ctx.createRadialGradient(cxp, cyp, R * 0.6, cxp, cyp, R * 1.7);
        ga.addColorStop(0, `rgba(${P.glow},${((lightMode ? 0.06 : 0.05) * anim.glow).toFixed(3)})`);
        ga.addColorStop(1, `rgba(${P.glow},0)`);
        ctx.fillStyle = ga;
        ctx.fillRect(0, 0, W, H);
      }

      /* orbit ring */
      ctx.beginPath();
      ctx.arc(cxp, cyp, ringR, 0, Math.PI * 2);
      ctx.strokeStyle = `rgba(${P.line},${((lightMode ? 0.08 : 0.05) + (lightMode ? 0.16 : 0.13) * anim.ring).toFixed(3)})`;
      ctx.lineWidth = 1 * d;
      ctx.stroke();

      /* bright arc chasing the satellite while connecting */
      if (anim.halo > 0.05) {
        for (let i = 0; i < 26; i++) {
          const a0 = sat - 0.055 * i;
          const aa = (1 - i / 26) * (lightMode ? 0.5 : 0.4) * anim.halo;
          ctx.beginPath();
          ctx.arc(cxp, cyp, ringR, a0 - 0.055, a0);
          ctx.strokeStyle = `rgba(${P.spark},${aa.toFixed(3)})`;
          ctx.lineWidth = 1.4 * d;
          ctx.stroke();
        }
      }

      /* satellite */
      const sx = cxp + Math.cos(sat) * ringR;
      const sy = cyp + Math.sin(sat) * ringR;
      const sg = ctx.createRadialGradient(sx, sy, 0, sx, sy, 11 * d);
      sg.addColorStop(0, `rgba(${P.spark},${(0.5 * anim.ring + 0.08).toFixed(3)})`);
      sg.addColorStop(1, `rgba(${P.spark},0)`);
      ctx.fillStyle = sg;
      ctx.beginPath();
      ctx.arc(sx, sy, 11 * d, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(sx, sy, 2.1 * d, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${P.spark},${(0.25 + 0.75 * anim.ring).toFixed(3)})`;
      ctx.fill();

      /* sphere body */
      const g = ctx.createRadialGradient(cxp - R * 0.35, cyp - R * 0.4, R * 0.1, cxp, cyp, R * 1.02);
      g.addColorStop(0, `${P.core[0]}${(0.9 * alpha).toFixed(3)})`);
      g.addColorStop(0.75, `${P.core[1]}${(0.92 * alpha).toFixed(3)})`);
      g.addColorStop(1, `${P.core[2]}${(0.7 * alpha).toFixed(3)})`);
      ctx.beginPath();
      ctx.arc(cxp, cyp, R, 0, Math.PI * 2);
      ctx.fillStyle = g;
      ctx.fill();

      /* rim light */
      const rg = ctx.createLinearGradient(cxp - R, cyp - R, cxp + R, cyp + R);
      rg.addColorStop(0, `rgba(${P.rim[0]},${((lightMode ? 0.16 : 0.22) * alpha).toFixed(3)})`);
      rg.addColorStop(0.45, `rgba(${P.rim[0]},0.02)`);
      rg.addColorStop(1, `rgba(${P.rim[1]},${((lightMode ? 0.1 : 0.1) * alpha).toFixed(3)})`);
      ctx.strokeStyle = rg;
      ctx.lineWidth = 1.1 * d;
      ctx.stroke();

      /* land dots */
      const pts = ptsRef.current;
      if (pts) {
        const n = pts.length / 3;
        const cosS = Math.cos(spin);
        const sinS = Math.sin(spin);
        const ratio = R / (114 * d);
        for (let i = 0; i < n; i++) {
          const x0 = pts[i * 3];
          const y0 = pts[i * 3 + 1];
          const z0 = pts[i * 3 + 2];
          const x1 = x0 * cosS + z0 * sinS;
          const z1 = -x0 * sinS + z0 * cosS;
          const z2 = y0 * sinT + z1 * cosT;
          if (z2 < -0.25) continue;
          const y1 = y0 * cosT - z1 * sinT;
          const depth = (z2 + 1) / 2;
          const a = alpha * (0.16 + 0.84 * depth * depth) * (lightMode ? 0.82 : 1);
          ctx.beginPath();
          ctx.arc(cxp + x1 * R, cyp + y1 * R, Math.max(0.4, 1.05 * d * ratio * (0.5 + 0.6 * depth)), 0, Math.PI * 2);
          ctx.fillStyle = `rgba(${P.dot},${a.toFixed(3)})`;
          ctx.fill();
        }
      }

      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
    };
  }, []);

  return (
    <button
      onClick={onToggle}
      aria-label="连接开关"
      className="relative block aspect-square w-full max-w-[356px] select-none"
    >
      <canvas ref={canvasRef} className="absolute inset-0 h-full w-full" />
      {/* center status */}
      <div className="pointer-events-none absolute inset-0 grid place-items-center">
        <div
          className="flex aspect-square h-[46%] flex-col items-center justify-center rounded-full border bd2 backdrop-blur-[2px]"
          style={{ background: "var(--globe-core)" }}
        >
          {state === "connected" ? (
            <>
              <span className="t3 text-[11.5px]">已连接</span>
              <span className="tnum t1 mt-1 text-[21px] font-semibold tracking-[0.07em]">{fmtHMS(seconds)}</span>
              <span className="mt-1.5 flex items-center gap-1.5 text-[11.5px] font-medium" style={{ color: ACCENT }}>
                <MiniBars level={4} size={10} />
                稳定
              </span>
            </>
          ) : state === "connecting" ? (
            <>
              <Loader2 size={17} className="t2 animate-spin" />
              <span className="t3 mt-2 text-[11.5px]">连接中</span>
            </>
          ) : (
            <>
              <span className="t4 text-[12.5px]">未连接</span>
              <span className="t6 mt-1.5 text-[9.5px] tracking-[0.12em]">轻点地球开始连接</span>
            </>
          )}
        </div>
      </div>
    </button>
  );
}
