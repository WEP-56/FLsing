import type { ConnState, Mode, NodeT } from "./ui";

export interface IpInfo {
  ip: string;
  region: string;
  isp: string;
  exit: boolean;
}

/* ---------------------------------------------------------------------------
 * 生产环境接入第三方 IP 检测服务时，仅需替换本函数内部实现，例如：
 *
 *   const r = await fetch("https://ipapi.co/json/");
 *   const d = await r.json();
 *   return { ip: d.ip, region: `${d.country_name} · ${d.city}`, isp: d.org, exit };
 *
 * 候选接口：ip-api.com（无需 key）/ ip.sb / ipinfo.io / ipapi.co
 * ------------------------------------------------------------------------ */

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

const LOCAL = { prefix: "120.232.18", region: "中国 · 广州", isp: "China Mobile" };

const EXIT: Record<string, { prefix: string; region: string; isp: string }> = {
  JP: { prefix: "203.104.203", region: "日本 · 东京", isp: "NTT Communications" },
  US: { prefix: "23.129.64", region: "美国 · 洛杉矶", isp: "Cogent" },
  SG: { prefix: "103.6.146", region: "新加坡", isp: "StarHub" },
  DE: { prefix: "185.220.101", region: "德国 · 法兰克福", isp: "Hetzner" },
  HK: { prefix: "43.230.16", region: "中国香港", isp: "HGC" },
  GB: { prefix: "185.82.216", region: "英国 · 伦敦", isp: "Virgin Media" },
};

const octet = () => 2 + Math.floor(Math.random() * 252);

export async function fetchIpInfo(
  conn: ConnState,
  mode: Mode,
  node: NodeT | null,
): Promise<IpInfo> {
  await delay(620 + Math.random() * 560);
  const exit = conn === "connected" && mode !== "direct" && !!node;
  const src = exit && node ? EXIT[node.code] ?? LOCAL : LOCAL;
  return { ip: `${src.prefix}.${octet()}`, region: src.region, isp: src.isp, exit };
}
