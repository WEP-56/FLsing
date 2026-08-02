# FLsing 开发交接

更新时间：2026-08-01

本文件记录设置项进度、插件分支状态和当前开发主线。设置完整规划见 [Settings-Roadmap.md](Settings-Roadmap.md)。

## 当前主线

**任务主线已切换为：分支开发——内核通信能力增强。**

- T2 设置开发暂停，已完成的 DNS、TUN 和路由覆写保持现状，不继续扩展复杂 DNS。
- 配置校验闭环已完成；后续继续在 `WEP-56/flutter_sing_box` 分支补齐稳定、可测试的 libbox 通信 API，再由 FLsing 消费。
- `Libbox.checkConfig` 已从 FLsing 的 `MainActivity` 下沉到插件，应用层不再直接编译依赖 libbox。

## 协作与验证边界

- Codex 只执行 `flutter analyze`、`flutter test`、格式化和差异检查等基础代码验证。
- APK 构建、安装、真机、真实网络、VPN 行为和其他复杂场景由用户执行。
- 涉及复杂或真实环境验证时，Codex 仅提供简短、可操作的测试项，不代替用户执行。

## 最近验收记录

- 2026-07-31：GitHub Actions APK 构建通过。
- 2026-07-31：真实手机安装、基础 VPN 连接和网络访问测试通过，未发现明显问题。
- 2026-08-01：优先测试八项和高级网络七项全部通过，包括授权与生命周期、网络切换、通知、重载、手动 DoH/DoT、三种 TUN 栈、IP 模式和路由策略。
- 2026-08-01：整组及非内核单节点测速正常；单 outbound 内核测速因 Android 禁止访问 `127.0.0.1` 明文 HTTP 失败，已补充精确 loopback 放行，待新包复测。
- 2026-08-01：发现重连后连接计时偶发保持 `00:00:00`；根因为已取消的 Timer 未置空，已修复并补充回归测试，待新包复测。
- 设置备份与恢复尚未进行真机验收。

## 当前状态

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| T0 可靠性与诊断 | 已完成 | 已提交并通过既有验收。 |
| T1 高频控制 | UI 与持久化完成 | 分应用代理在当前插件中的 Android 应用代码被注释，内核闭环转入插件主线修复。VPN bypass 不做。 |
| T2 高级网络 | 第二阶段完成 | DNS、TUN、路由策略与安全本地覆写已实现；复杂 DNS、缓存等仍待开发。 |
| T3 特权/专家能力 | 未开始 | 不应提前实现。 |
| Android-only 插件分支 | 已提交并推送 | 提交 `316fdf5` 已补充单 outbound 测速、宿主应用命名和文档驱动 example，并清理旧示例资产。 |
| 内核通信能力 | 第二阶段开发中 | 配置校验已迁移；单 outbound 内核测速的首轮真机问题已定位并修复，待新包复测。 |

## 插件分支现状

- 插件独立仓库位于 `D:\FLsing\flutter_sing_box`，远端为 `https://github.com/WEP-56/flutter_sing_box.git`，当前分支为 `master`。
- FLsing 的 `pubspec.yaml` 已改为 Git 依赖 `WEP-56/flutter_sing_box` 的 `master`；`pubspec.lock` 当前固定在远端提交 `316fdf5`。
- FLsing 的 `.gitignore` 已排除 `/flutter_sing_box/`。插件和 FLsing 是两个独立 Git 工作区，不能在 FLsing 提交中混入插件源码。
- 插件已删除 `ios/`、`example/ios/` 和 iOS 平台注册；默认订阅 User-Agent 收敛为 Android，移除无用的 `device_info_plus` 与 `package_info_plus` 依赖。
- 插件结构、运行链路、包体来源和后续维护边界见 `flutter_sing_box/docs/Android-Architecture.md`。
- 插件旧 `example` App 资产已删除，改为能力矩阵和分主题 Markdown 使用范例。
- 插件基础验证通过：`flutter analyze --fatal-infos` 无问题，`flutter test` 6 项通过；FLsing 更新远端插件锁定后，`flutter analyze --fatal-infos` 无问题，`flutter test` 28 项通过。
- 删除非 Android 文件不会直接缩小 APK。Android 包体主要由 `libbox.aar` 中的 ABI 原生库和启用功能决定，应优先使用 ABI 拆分或 AAB，再评估自维护 libbox 产物。

## 已完成设置

### T0：可靠性与诊断

- 设置页按类别组织，并明确设置的生效时机。
- 断线后自动重连：区分用户主动断开、VPN 授权拒绝和内核异常，使用退避重试。
- 日志查看、清空、复制/分享脱敏日志，以及连接诊断快照。
- 电池优化状态与系统引导。
- 关于页手动检查更新；没有自动检查、下载或安装。

### T1：高频控制

- 启动后自动连接：默认关闭，只恢复用户此前保持的连接；不使用 Android 开机自启。
- 分应用代理：关闭、仅代理、排除三种模式的 UI 与持久化已完成，支持应用搜索和系统应用隐藏；当前插件 `BoxService` 中实际调用 `includePackage/excludePackage` 的代码被注释，尚不能视为内核闭环。
- 系统 HTTP 代理：仅在活动 TUN 配置提供本地 HTTP 代理时可用。
- 通知栏实时速率：处理 Android 13+ 通知权限。
- 订阅更新策略：更新间隔、仅 Wi-Fi、失败重试、最近失败原因。
- 设置备份与恢复：不包含订阅链接、节点配置、安装包缓存和临时错误。
- VPN bypass：**未实现且不应展示**。`flutter_sing_box` 当前 Android 实现没有启用 `allowBypass()`。

### T2：高级网络第一阶段

- 独立的“高级网络”入口及 DNS、TUN 两个三级页面。
- DNS 三档：使用订阅、FLsing 默认、手动 DoH/DoT。
- DNS 参数：IPv4/IPv6 策略、DNS 缓存、独立缓存、FakeIP、客户端子网。
- TUN 覆写：MTU、协议栈、自动/严格路由、嗅探、覆盖目标、IPv4/IPv6 接口地址、排除路由。
- 默认不覆写订阅；DNS/TUN 均支持单项恢复默认。连接中保存会重载 VPN，未连接时下次连接生效。
- 本地覆写链路：订阅原配置复制到 `using_config` 后再打补丁，不修改订阅原文。
- 保存前通过 Android 通道调用 `Libbox.checkConfig` 校验候选配置；成功后用临时文件和备份文件替换 `using_config`。中断写入可在下次初始化恢复。
- 高级网络设置纳入现有设置备份；旧备份缺少该字段时保持兼容。

### T2：路由策略

- 新增独立“路由策略”三级页面；默认关闭覆写并完整保留订阅路由。
- 支持默认出口、自动探测出口接口、双栈/仅 IPv4/仅 IPv6。
- 常用规则支持私有网络直连、中国大陆规则直连和阻止 QUIC。
- 自定义规则支持完整域名、域名后缀/关键字、IP CIDR、端口/范围、进程名、应用包名、Wi-Fi SSID、网络类型和 IP 版本。
- 自定义规则可启停、编辑、删除和拖动排序；出口可选择订阅中的实际 outbound 或沿用默认出口。
- 写入前校验 CIDR、端口、IP 版本、规则顺序、规则集和 outbound 引用；候选配置继续通过 `Libbox.checkConfig` 后原子替换。
- 每次设置变更都从订阅原配置重新生成 `using_config`，避免重复保存累积本地规则。
- 路由设置已纳入高级网络 JSON，因此随现有设置备份导出和恢复。

### 测速行为增强

- 单节点直连模式继续使用节点物理地址 TCP 握手，只更新目标节点。
- 单节点智能模式在 VPN 已连接时、内核模式在 VPN 已连接后，调用插件 `urlTestOutbound` 通过目标 outbound 完成内核测速；断开时不会伪装成代理测速。
- 全节点测速继续遵循“智能 / 直连 / 内核”设置；内核模式仍使用整组 `urlTest(groupTag)`。
- 已补充单元测试，覆盖单节点直连、断开提示、已连接单 outbound 内核测速与全节点策略保留。

## 已知问题与注意事项

- 手动 DoH/DoT、三种 TUN 协议栈、三种 IP 模式、排除路由、复杂路由规则、订阅切换和连接中重载已通过真机验收；设置备份与恢复仍待验证。
- 单 outbound 测速依赖活动配置中的认证 loopback Clash API；FLsing Network Security Config 已只为 `127.0.0.1` 放行明文 HTTP，待新包复测目标 outbound、失败结束 loading 和超时行为。
- Android 系统 VPN 会话名和通知标题读取宿主应用标签的改动已通过真机验收，显示为 `FLsing`。
- 连接计时器已修复取消后未清空引用的问题，避免重连后停在 `00:00:00`，待新包复测。
- `independent_cache`、入站 `sniff` 与 `sniff_override_destination` 在更高 sing-box 版本已废弃；当前固定的 libbox 1.13.14 仍可用。升级内核时先做兼容性审查。
- 系统 HTTP 代理依赖订阅提供的 `tun.platform.http_proxy`；外部导入配置不一定兼容。
- 设置恢复仍复用通用配置文件选择器，原生系统选择器不会专门过滤备份 JSON。
- 当前插件的分应用代理包名应用代码被注释；恢复后需真机分别验证“仅代理”和“排除”模式，不能只检查设置值是否写入。
- 插件 `serviceReload` 实际触发服务重启，现有 Future 只表示命令提交，不表示新配置已成功启动；FLsing 仍依赖状态流和固定延迟收敛。
- `onServiceAlert` 的类型和消息当前只写原生日志，Dart 只收到 stopped 状态，自动重连无法区分真实内核错误。

## 内核通信增强路线

### 第一阶段：配置校验闭环（已完成）

1. 在插件 `FlutterSingBox`、`FlutterSingBoxPlatform` 和 MethodChannel 实现中新增 `checkConfig(String configuration)`。
2. Android 插件侧在后台线程调用 `Libbox.checkConfig`，为空配置和内核校验失败提供稳定错误码，不能阻塞主线程。
3. 补充真实的 MethodChannel 单元测试，覆盖方法名、参数、成功返回和 `PlatformException`；现有插件测试仅验证默认实例，覆盖不足。
4. FLsing 的 `PlatformConfigurationValidator` 改为调用插件 API，保持现有依赖注入和高级配置服务测试不变。
5. 迁移验证通过后，删除 `MainActivity` 中的 `flsing/configuration` 通道、`Libbox` import，以及 `android/app/build.gradle.kts` 中仅为配置校验添加的 libbox 直接依赖。

### 第二阶段：状态、错误与操作反馈

1. 新增 `getProxyState()` 和结构化 `serviceAlertStream`；当前 `onServiceAlert` 只写原生日志并把状态改为 stopped，Dart 无法获得错误类型和消息。
2. 恢复并验证 `BoxService` 中的 `includePackage/excludePackage` 调用，让现有分应用设置真正进入 Android `VpnService.Builder`。
3. 为启动、停止、重载、模式切换和出口选择统一参数校验、错误码和异步执行策略；逐步替换 FLsing 的固定延迟等待。
4. 评估整组 `urlTest` 的完成反馈。当前 Future 只表示命令已提交，实际结果依赖 `groupStream`，没有请求关联和明确超时。
5. 核对当前 libbox command API 后，再决定是否公开日志清理、日志级别、连接明细和服务状态快照；不为内核未支持的能力设计空接口。

### 第三阶段：维护与兼容协议

1. 增加插件能力查询与 libbox 版本约束，避免 FLsing 依赖某个方法但运行时插件不支持。
2. 为 MethodChannel/EventChannel 定义稳定的数据结构和错误模型，减少字符串方法名、动态 Map 与 JSON 字符串漂移。
3. 把仍属于内核职责的配置、缓存和诊断桥接逐步下沉到插件，FLsing 只保留系统文件选择、安装包、分享和设备权限等应用能力。

## 暂停的 T2 队列

1. 复杂 DNS 策略：规则分流、默认解析器、响应规则和复杂规则表单。
2. 自动选优参数：`urltest` URL、间隔、容差与自动组默认节点。
3. 日志级别、DNS/规则缓存控制、规则集更新周期、内核缓存维护和手动更新通道选择。

## 两仓提交顺序

1. 在 `flutter_sing_box` 仓库完成改动、基础测试、提交并推送 `master`。
2. 在 FLsing 执行 `flutter pub get`，确认 `pubspec.lock` 的 `resolved-ref` 更新到插件新提交。
3. 再提交 FLsing 的依赖迁移和应用层桥接删除；插件提交未推送前，不要把本地插件能力当作远端依赖已可用。

## 设置实现约束

- 每项设置必须明确“立即生效 / 重载 VPN / 下次连接 / 重启应用”中的一种，不能只写入而不生效。
- 高风险覆写先生成候选配置并校验；失败不能替换当前可用 `using_config`。
- 高级能力应放在二级或三级页面，默认保持订阅配置；不要为简化 UI 删除已有能力。
- 不实现多语言应用 UI；当前设置文案维持中文。
- 不实现自动更新检查、下载或安装；更新只能由用户从“设置 → 关于 → 版本”手动发起。
