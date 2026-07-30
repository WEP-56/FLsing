# FLsing 设置补全路线图

## 目标与边界

FLsing 是 Android 上的日常代理客户端，设置应让用户能解决连接、订阅、节点和诊断问题，不应把 sing-box 的全部参数直接暴露出来。每个设置都必须有明确的生效时机：立即生效、重载服务、重新连接或重启应用；不能出现仅保存、不生效的开关。

本路线图以 `example/sing-box-for-android` 为参考，但不照搬其多用途工具定位。当前 FLsing 已有主题、代理模式、测速方式/地址、订阅自动更新、规则库更新和手动应用更新。`设置`页中“断线后自动重连、启动后自动连接、分应用代理、DNS 设置、日志查看”仍是占位项。

小白向只约束默认值、文案和导航层级，不限制能力范围。`flutter_sing_box` 已支持或暴露配置模型的能力均应进入实现范围；高风险或低频项放入“高级网络”或“开发者设置”，默认关闭并提供恢复默认值。

## 优先级定义

| 级别 | 含义 | 进入条件 |
| --- | --- | --- |
| T0 | 连接成功率、故障定位和已有占位功能的闭环 | 必须有 Android/内核实现、持久化、UI、重载语义和测试 |
| T1 | 高频的个性化控制，能明显扩大日常可用场景 | T0 稳定，且不增加 Root/Shizuku 等前置条件 |
| T2 | 面向熟悉网络概念的高级选项 | 独立高级页、可恢复默认值、对错误配置有防护 |
| T3 | 特权、企业或非 FLsing 主定位的能力 | 仅在明确的用户需求和完整维护方案下立项 |

## T0：可靠性与诊断闭环

| 设置项 | 用户可见行为 | 实现要点 | 参考来源 |
| --- | --- | --- | --- |
| 设置生效模型 | 每个条目明确显示“立即生效 / 重新连接后生效”，变更后只执行一次对应动作 | 为 `AppSettings` 增加带类型的设置项；`AppState` 统一处理 reload/reconnect，避免 UI 直接散写 MMKV | 参考项目在每项设置后显式触发 Reload 或 Restart |
| 断线后自动重连 | VPN 异常停止后按退避策略重新连接；用户主动断开绝不重连 | 区分 `startedByUser`、主动停止、权限拒绝和内核错误；初始 2 秒、上限 30 秒、网络恢复后立即尝试 | 参考项目持久化 `startedByUser`，服务状态与启动意图分离 |
| 日志查看与导出 | 设置中进入只读日志页，可暂停滚动、复制、清除和分享脱敏日志 | `FlutterSingBox.logStream` 已可用；服务层新增日志流，限制内存条数，导出前遮盖订阅 URL、token 和本地路径 | 参考项目的日志页、复制/分享日志能力 |
| 后台运行与电池优化引导 | 设置显示电池优化状态，按需打开系统“忽略电池优化”页面 | 仅引导，不能声称保证后台常驻；在 Android 原生侧查询状态并处理机型差异 | `ServiceSettingsScreen` 的 Background Permission |
| 连接诊断快照 | 一次性展示 VPN 状态、内核版本、当前模式、活动订阅、节点、出口 IP、最近错误和规则库时间 | 复用已有诊断信息；新增“复制诊断信息”，不包含订阅地址和节点密钥 | 参考项目 Core/Log 的故障定位路径 |

T0 验收：飞行模式恢复、进程被系统回收、VPN 权限拒绝、内核启动失败和规则库更新失败均有可解释反馈；日志与诊断足以让用户提交有效问题报告。

## T1：高频控制

| 设置项 | 用户可见行为 | 实现要点 | 参考来源 |
| --- | --- | --- | --- |
| 启动后自动连接 | 应用启动完成、内核初始化和活动订阅就绪后，如用户开启该选项，自动连接上一次活动订阅/节点；默认关闭 | 不使用 `RECEIVE_BOOT_COMPLETED` 或 `BootReceiver`；无订阅、用户上次主动断开或 VPN 权限缺失时不强行连接 | 复用应用启动状态与用户连接意图 |
| 分应用代理 | 关闭、白名单、黑名单三种模式；应用选择页按名称搜索、显示包名，默认隐藏系统应用 | `flutter_sing_box` 的 `CsSettingsStorage` 和 Android `VPNService` 已支持 include/exclude 包名；需要原生列举已安装应用及 Android 11+ 可见性策略，保存后重连 VPN | 参考项目 `ProfileOverrideScreen`；插件 Android VPN 侧 `addAllowedApplication`/`addDisallowedApplication` |
| VPN 绕过开关 | 允许应用调用 Android 的 VPN bypass；默认关闭并解释影响 | 写入 TUN/VPN 覆写并重载服务；仅在内核实际支持时展示 | 参考项目 Service 的 Allow Bypass |
| 通知样式 | 显示或隐藏通知中的实时上/下行速率；保持系统前台服务通知 | 需要扩展插件 Android 前台通知，处理 Android 13 通知权限；该项不控制 VPN 是否有通知 | 参考项目 Dynamic Notification |
| 系统 HTTP 代理 | 对支持 Android 系统 HTTP Proxy 的 TUN 配置提供开关；默认跟随订阅配置 | TUN `platform.http_proxy` 开启时，插件 Android `VPNService` 已调用 `setHttpProxy`；保存后重连 VPN | 插件 `SettingsManager.systemProxyEnabled` 与 `VPNService.openTun` |
| 订阅更新策略 | 保留已有开关和时长，补充“仅 Wi-Fi”“失败重试”和“上次失败原因” | 使用 Android 网络能力判断；订阅更新不得阻塞首屏或 VPN 启动 | 参考项目的订阅自动更新概念，结合 FLsing 现有实现 |
| 设置备份与恢复 | 导出不含订阅凭据的应用偏好；恢复前预览并确认 | 使用版本化 JSON；订阅 URL、节点配置、安装包缓存默认不导出 | 参考项目对分应用列表的导入/导出思路 |

T1 验收：分应用白名单/黑名单在重连后由 Android `VpnService` 实际生效；启动后自动连接不会违背用户主动断开的意图；每项有系统权限失败提示。

## T2：高级网络与维护

| 设置项 | 用户可见行为 | 实现要点 | 参考来源 |
| --- | --- | --- | --- |
| DNS 策略 | 默认、使用订阅、手动 DNS 三档；手动模式仅提供 DoH/DoT 地址与策略组选择 | 通过 `SingBoxService.applySettingsPatch` 写入配置的 `dns` 段；先做 JSON schema 校验，失败不覆盖当前可用配置 | 参考项目将 Core/Profile Override 与主设置分离 |
| DNS 完整策略 | DNS 缓存、独立缓存、FakeIP、客户端子网、规则分流、默认解析器与响应规则 | 插件 `Dns`/`DnsRule` 模型已覆盖这些字段；用预设模式组织，复杂规则进入表单或 JSON 覆写 | 插件 `Dns`、`DnsRule` 模型 |
| TUN 网络参数 | MTU、协议栈、自动/严格路由、嗅探、覆盖目标、IPv4/IPv6 地址与路由排除 | `flutter_sing_box` 配置模型已有 `mtu`、`stack`、`auto_route`、`strict_route` 等字段；所有变更要求重连和一键恢复默认 | 插件 `Inbound` 和 Android `VPNService.openTun` |
| 路由策略 | 默认出口、自动探测接口、IPv4/IPv6、域名/IP/端口/进程/包名/Wi-Fi/网络类型规则、规则集更新周期 | 用“常用规则”与“自定义规则”两层呈现；写入前校验规则顺序和目标 outbound | 插件 `Route`、`RouteRule`、`RuleSet` 模型 |
| 自动选优参数 | `urltest` 测试 URL、间隔、容差和自动组默认节点 | 现有测试 URL 迁入此项；配置变更后重载服务，手动测速仍保持独立逻辑 | 插件 Outbound 模型与 FLsing 当前 urltest 配置 |
| 日志级别与缓存 | trace/debug/info/warn/error，DNS/规则缓存容量与过期策略 | 默认 `info`；修改日志级别重载服务，清理缓存不可删除活动配置 | 插件 `Log`、`Dns`、`Experimental.cache_file` 模型 |
| 连接配置覆写 | 对活动订阅添加本地覆写而不修改订阅原文，例如 DNS、路由、TUN 参数 | 采用“订阅原配置 + 覆写补丁”生成 using config；切换订阅和更新订阅后重放覆写 | 参考项目 `ProfileOverrideScreen` |
| 更新通道 | 手动检查的稳定版/Beta 版选择；默认稳定版 | GitHub API 分别读取 release/latest 与 prerelease；沿用现有“无自动检查、无自动更新”原则 | 参考项目 Update Track，但去除自动检查/自动安装 |
| 内核维护 | 显示内核版本、规则库大小、缓存大小；提供清理规则缓存和安全重置 | 清理前说明影响，不能删除当前使用配置；保留诊断日志导出 | 参考项目 Core 的 data size、working directory、cache actions |

T2 验收：任一无效 DNS/TUN/路由覆写都不会让已连接服务失去可恢复路径；高级页能单项恢复默认并展示下一次生效条件。

## T3：特权与专家能力

| 项目 | 用户可见行为 | 实现要点 |
| --- | --- | --- |
| Root 自动重定向 | 在已授权 Root 设备上启用透明重定向 | 插件 `OverrideOptions.autoRedirect` 与 Android `SettingsManager.autoRedirect` 已有支撑；必须检测 Root、显示风险、提供停止服务后的回滚 |
| 本地代理服务模式 | VPN 与本地 SOCKS/HTTP 代理服务之间切换 | 插件存在 `ProxyService` 和 `service_mode`；FLsing 需要补齐 Android manifest、端口冲突检测、局域网暴露确认和服务状态 UI |
| 出站传输调优 | UDP over TCP/stream、MUX、QUIC 拥塞控制、0-RTT、MTU discovery、TLS/SNI/ALPN 等 | 对协议和订阅配置有强依赖；只对匹配的节点类型显示，保留订阅默认与逐项重置 |
| 实验性 Clash API / 外部控制器 | 本地面板或外部工具控制当前实例 | 插件 `Experimental.clash_api` 模型可配置；必须有随机密钥、默认仅 loopback、访问控制和重启提示 |
| 原始配置编辑器 | 对完整 sing-box JSON 做查看、编辑、验证、差异与回滚 | 这是全部未结构化配置字段的最终入口；保存前运行 `sing-box check` 等价校验，失败时保持上一份 using config |
| 内存限制开关 | 调整内核进程的内存限制策略 | 插件 Android `disable_memory_limit` 已有设置键；默认不展示，须说明耗电和系统稳定性风险 |
| Shizuku/特权安装 | 在明确授权后提供更高权限的系统操作 | 需独立权限、可用性检测和完整安全审计；不改变当前手动更新的默认流程 |

## 能力覆盖清单

下表确保插件已可接入的设置不会因导航层级而遗漏。除“更新自动化”外，均应按对应优先级实现。

| 能力域 | 可设置项 | 推荐层级 |
| --- | --- | --- |
| 应用与服务 | 主题、通知实时速率、后台/电池优化、启动后自动连接、自动重连、诊断与日志导出 | T0-T1 |
| VPN 平台 | 分应用白名单/黑名单、系统 HTTP 代理、VPN bypass、IPv4/IPv6 路由、路由排除、MTU、协议栈、严格路由 | T1-T2 |
| 订阅与规则 | 更新间隔、仅 Wi-Fi、失败重试、测速地址、自动选优间隔/容差、规则集来源/更新时间/下载出口 | T1-T2 |
| DNS | 服务器、DoH/DoT、缓存、FakeIP、客户端子网、规则分流、响应规则、默认解析器 | T2 |
| 路由 | 默认出口、规则集、域名/IP/端口/进程/包名/Wi-Fi/网络类型匹配、规则顺序 | T2 |
| 节点与传输 | TLS/SNI/ALPN、MUX、UDP、QUIC、拥塞控制、0-RTT、协议级 MTU 发现 | T3 |
| 内核与实验性功能 | 日志级别、缓存文件、Clash API、外部 UI、服务模式、自动重定向、内存限制、原始配置编辑 | T2-T3 |

## 明确不自动化的参考设置

参考项目提供“自动检查更新、自动下载/静默安装、更新源、GitHub Token”。FLsing 已确定为用户在“设置 - 关于 - 版本”主动触发检查，因此不实现自动检查和自动下载/安装开关。更新轨道、多个来源和 Token 可作为 T2/T3 的手动检查能力，但默认仍使用 GitHub 稳定版。

参考项目的“中国应用自动排除”依赖应用枚举、地区判断和 Shizuku/Root 兼容逻辑。FLsing 的分应用代理先做用户明确选择的白名单/黑名单；自动规则可在 T3 作为可审查的规则包功能，而非隐式行为。

## 建议的设置页信息架构

主页面保持紧凑，T1/T2 功能进入二级页：

1. 外观：主题。
2. 代理方式：规则、全局、直连。
3. 测速：方式、测试链接。
4. 订阅与规则库：更新策略、规则库更新。
5. 连接：自动重连、启动后自动连接、后台运行、电池优化。
6. 应用代理：分应用代理入口和当前模式摘要。
7. 高级网络：DNS、TUN 参数、配置覆写，只在 T2 出现。
8. 诊断：日志、诊断快照、内核与缓存维护。
9. 关于：版本检查、开源许可。

## 实施顺序

先完成 T0 的“设置生效模型”，再做自动重连与日志；这两项会成为后续设置的共同基础。随后做 T1 分应用代理和启动后自动连接。T2 仅在 T0/T1 的重连、诊断和配置补丁经过真机验证后开始，避免高级项把配置状态带回不可解释的分叉。

## 调研依据

- 参考项目设置入口：`example/sing-box-for-android/app/src/main/java/io/nekohasekai/sfa/compose/screen/settings/SettingsScreen.kt`。
- 参考项目应用、服务、核心和配置覆写设置：同目录的 `AppSettingsScreen.kt`、`ServiceSettingsScreen.kt`、`CoreSettingsScreen.kt`、`ProfileOverrideScreen.kt`。
- 参考项目设置数据模型：`example/sing-box-for-android/app/src/main/java/io/nekohasekai/sfa/database/Settings.kt`。
- FLsing 当前设置与占位项：`lib/ui/pages/settings_page.dart`、`lib/data/services/app_settings.dart`。
- 已验证的插件能力：`flutter_sing_box` 的 `logStream`、`CsSettingsStorage` 与 Android `VPNService` 的应用白/黑名单实现。
