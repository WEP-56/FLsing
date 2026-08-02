# FLsing 开发交接（Agent 开场文档）

更新时间：2026-08-02

本文档是新会话 / 新 agent 的开场briefing：项目是什么、仓库怎么组织、哪些流程绝不能做错、当前进行到哪里。深入细节看对应文档：

- 设置功能全景与优先级：[Settings-Roadmap.md](Settings-Roadmap.md)
- 插件结构、运行链路、维护边界：`flutter_sing_box/docs/Android-Architecture.md`
- 上游同步流程（remote/triage 三分类/合并/验证/lockfile 前移）：`flutter_sing_box/docs/Upstream-Sync.md`
- 插件 API 用法（生命周期/配置/事件流/测速/宿主集成/验收）：`flutter_sing_box/example/guides/01~06`

## 一、项目是什么

FLsing 是 Android 上的 Flutter + sing-box 代理客户端，面向日常用户，中文 UI。VPNService、内核通信、配置模型来自插件 `flutter_sing_box`。应用当前版本 1.2.6+7；插件版本自 1.1.5 起跟随上游版本号（「冻结 1.1.4」策略已作废）。插件工作区已同步上游 v1.1.5（libbox 1.13.15），但 FLsing 构建实际编译哪个插件版本以 `pubspec.lock` 的 `resolved-ref` 为准——当前仍锁在 `df98246`（1.1.4 / libbox 1.13.14），前移步骤见第六节状态表。

## 二、仓库结构与两仓关系（先读这节）

```
D:\FLsing                    ← FLsing 应用仓库（git）
├── flutter_sing_box\        ← 插件仓库（独立 git 工作区，被 FLsing 的 .gitignore 排除）
│     remote: https://github.com/WEP-56/flutter_sing_box.git (master)
├── example\                 ← UI 设计参考与 sing-box-for-android 源码（git 忽略，只读参考）
├── lib\ / test\ / docs\     ← 应用代码、测试、文档
└── pubspec.yaml             ← 插件以 git 依赖引入（url + ref: master）
```

关键事实：

1. **FLsing 与插件是两个独立仓库**。不能在 FLsing 提交中混入插件源码，反之亦然。
2. FLsing 通过 **git 依赖**消费插件，构建时代码取自 **pub 缓存里 `pubspec.lock` 锁定的那个提交**——不是本地 `flutter_sing_box\` 目录，也不是 GitHub master 最新。
3. 本地 `flutter_sing_box\` 目录只用于开发插件本身；改完必须走「提交 → 推送 → 前移 lockfile」流程才会进入 FLsing 构建。

## 三、依赖流程铁律（2026-08-02 锁文件事故复盘）

**事故经过**：修复"内核单节点测速 502"时，插件侧修复已提交并推送到 GitHub master（`df98246`），FLsing 侧修复也已提交。但 `pubspec.lock` 的 `resolved-ref` 仍锁在修复前的 `316fdf5`——`flutter pub get` 永远沿用锁定值，GitHub Actions 也执行 `pub get`，于是 CI 构建的 APK 一直编译旧插件，真机复测 502 依旧。用户与 agent 之间反复确认"插件代码是新的"（GitHub 上确实是新的），浪费了一轮完整的构建-安装-复测循环，最终靠 sing-box 日志（请求仍进 mixed 入站、被路由到远端节点）+ pub 缓存源码比对（无 `Proxy.NO_PROXY`）才定位到 lockfile。

**规则**：

1. `ref: master` 只在首次解析或显式 upgrade 时求值一次；此后 `flutter pub get`（本地和 CI）都按 `resolved-ref` 取代码。**改了插件，`pub get` 不会带来新代码。**
2. 插件改动生效的完整链路：插件仓库提交并推送 master → 在 FLsing 执行 `flutter pub upgrade flutter_sing_box`（纯本地操作，非发布）→ 确认 `pubspec.lock` 的 `resolved-ref` 已指向新提交 → **提交 lockfile** → 推送触发 CI。缺任何一环，CI 包就是旧插件。
3. 排查"修复为什么没生效"时，先查两处硬证据，再讨论其他：
   - `grep resolved-ref pubspec.lock`，与插件 `git log` 对比；
   - pub 缓存源码：`%LOCALAPPDATA%\Pub\Cache\git\flutter_sing_box-<resolved-ref>\`，直接看修复代码在不在。
4. 行为特征佐证：请求类修复可用 sing-box 日志判断（例：控制器请求修复后不应再出现 `inbound/mixed` 条目）。
5. 附带教训：一次 `pub get` 曾因中断产生坏解析，把插件的 5 个传递依赖（dio/json_annotation 等）从 lock 里丢掉——遇到 lock 异常删 `.dart_tool` 重新 `pub get`；在本机连续执行 shell 命令时工作目录会漂移（曾把插件目录的 lock 当成 FLsing 的验证），**跑 flutter 命令前显式 `Set-Location`，验证文件用绝对路径**。

## 四、运行架构速览

- **进程模型**：主进程（Flutter UI + 插件通道）+ `:remote` 进程（VPNService + libbox 内核）。跨进程靠 AIDL + MMKV（全部 `MULTI_PROCESS_MODE`）+ libbox command 通道。
- **配置链路**：订阅原文存 `documents/profiles/profile_N.json`（元数据在 MMKV `cs_profile`）；激活时复制为 `using_config.json` 再由 `SingBoxService._patchUsingConfig` 打补丁（本地规则集、clash_api 控制器/密钥、`default_mode` 固定 `rule`、测速链接、高级网络覆写），`Libbox.checkConfig` 校验通过后原子替换。订阅原文永不修改。
- **订阅导入双管线**：分享链接类（vmess/vless/ss…）由 FLsing 自建解析 + 插件模板组装；sing-box JSON / Clash YAML 交给插件 `ProfileService`。两条管线都支持按订阅绑定的 User-Agent。
- **测速两种语义**：TCP 直连测物理可达（设备直接握手节点端口）；内核测速走 `urlTest(groupTag)`（整组，结果异步进 `groupStream`）或 `urlTestOutbound`（单点，插件经认证的回环 Clash API 同步返回，**强制 `Proxy.NO_PROXY`**）。
- **模式语义**：内核可用模式列表 = `default_mode` + 路由/DNS 规则引用过的 `clash_mode`；`cache_file`（cache.db）会持久化上次模式并在启动时优先恢复。FLsing 的策略：`default_mode` 固定写 `rule` 保证列表完整，服务 Started 后由 `AppState._applyModeToRunningService` 把用户偏好推送给内核（同时压制推送窗口内的旧模式事件）。
- **初始化韧性**：`SingBoxService.initialize` 分核心链路（MMKV/插件通道/using_config 目录，失败抛出）与尽力而为（规则集释放、配置补丁、订阅激活，失败记 `initializationWarnings`）；`AppState.initialize` 无论服务初始化成败都加载订阅数据并订阅事件流，连接时自动重试初始化。**订阅数据"消失"几乎从来不是数据丢了**，而是初始化中断导致 UI 没加载——数据在内部存储 MMKV，无 root 文件管理器只能看到外部目录的 cache.db 和 stderr.log，这是正常的。

## 五、当前主线：下一阶段工作三项（2026-08-02 定）

### 工作①：跟随上游更新（吸收 clash-sing/flutter_sing_box v1.1.5）

> **进展（2026-08-02）**：插件侧同步已完成（工作区待用户提交）。逐条 triage 实录、吸收/跳过结果与端口对账结论见 `flutter_sing_box/docs/Upstream-Sync.md` 附录 A 及插件 CHANGELOG 1.1.5 条目。实测与下文预判有出入：上游第 2、6 条（端口动态适配、状态流优化）实现全在 Windows 文件中，已按分歧区跳过。剩余步骤见第六节状态表。

fork（`WEP-56/flutter_sing_box`）相对上游 `clash-sing/flutter_sing_box` 只有两处**有意分歧**，永不回收上游对应改动：

- **客户端支持简化**：Android-only，已删除 iOS/桌面/Web 注册与旧 example 应用；
- **内核通信能力强化**：`checkConfig`、`urlTestOutbound`、模式校验转发等本分支自研 API。

除这两处外，上游其余更新都要同步，**版本号也随上游同步**（此前"冻结 1.1.4"的策略作废，插件 CHANGELOG 头部的声明需一并修改）。

[上游 v1.1.5](https://github.com/clash-sing/flutter_sing_box/releases/tag/v1.1.5) 待吸收清单：

1. libbox `1.13.14 → 1.13.15`（sing-box 内核升级）；
2. Clash API 端口支持动态适配变化；
3. 移除 Android 端未使用的位置权限；
4. 重构服务安装接口：参数收敛为 `HelperConfig` 对象，硬编码路径提取为常量；
5. 服务管理能力（uninstall / start / stop）上升到平台抽象层与门面；
6. 优化代理状态流控制器初始化与状态分发逻辑；
7. `FlutterSingBoxWindows` 委托 `HelperCli`，移除已迁移的辅助方法。

同步时逐条 triage，三分类处理：

- **直接吸收**：与分歧区无关的改动（如 1、2、3、6）；
- **分歧区跳过/裁剪**：`HelperConfig` / `HelperCli` / Windows 门面等主要服务于桌面端的部分（4、5、7 大概率属此类）——纯 Windows 实现跳过，但**平台接口/门面层的通用签名变化要跟**，保持与上游接口形状兼容，降低后续同步成本；
- **冲突区人工合并**：改动触及本分支强化过的文件（`FlutterSingBoxPlugin.kt`、方法通道、`SingBoxConnector` 等）时逐块合并，保住 NO_PROXY、模式校验、`checkConfig` 等自研能力。

集成检查点：

- libbox 升级按插件 Architecture 文档的验证矩阵过一遍（启动/停止/重载/网络切换/日志流/配置校验/两种测速），并审查废弃字段（`independent_cache`、入站 `sniff` 等）；
- "Clash API 端口动态适配"要与 FLsing 侧的端口逻辑（`_ensureClashApiPort` 分配、`_patchUsingConfig` 写入、插件 `readClashApiAccess` 从 using_config 读取）专门对账，确认两层逻辑不打架，必要时收敛为一处；
- 同步完成后：插件 analyze/test → 提交推送 → 按第三节铁律前移 FLsing lockfile → FLsing analyze/test → CI 真机验收。

原"内核通信第二阶段"遗留项（结构化服务告警、分应用代理 include/exclude 闭环、命令完成语义）在同步时评估：上游第 6 条可能已覆盖部分诉求，先吸收再决定自研排期。

### 工作②：制作上游同步流程文档

> **进展（2026-08-02）**：已完成。文档位于 `flutter_sing_box/docs/Upstream-Sync.md`（随插件仓库提交），已在本文档第一节索引登记。

产出 `flutter_sing_box/docs/Upstream-Sync.md`（建议路径），要求严谨、可被后续 agent 直接执行，至少涵盖：上游 remote 配置与 fetch 命令；按 release/commit 做差异 triage 的三分类标准（含分歧区文件清单）；合并策略选择（cherry-pick 为主还是 merge）；版本号与 CHANGELOG 同步规则；升级验证矩阵；FLsing 侧 lockfile 跟进步骤；真机验收清单。写完后在本文档第一节的索引中登记。

### 工作③：设置项补全（Roadmap T2 剩余 → T3）

按 [Settings-Roadmap.md](Settings-Roadmap.md) 恢复推进：

- T2 剩余：复杂 DNS 规则与响应规则、自动选优间隔/容差、规则集更新周期、日志级别与缓存、更新通道、内核维护；
- T3 随后启动，按 Roadmap 的进入条件逐项立项（Root 重定向、本地代理服务模式、出站传输调优、外部控制器、原始配置编辑器等），不做大爆炸式一次性实现。原"T3 不应提前实现"的约束更新为"按进入条件立项"。

## 六、当前状态（2026-08-02）

| 事项 | 状态 |
| --- | --- |
| 三问题修复（初始化韧性 / 单点测速 502 / 模式切换与跳回） | **已真机验收通过**（FLsing `c2ed39b`+`29c74a1`，插件 `df98246`） |
| 订阅自定义 User-Agent | **已真机验收通过**（`a6577f2`，预设 8 条 + 自定义，按订阅绑定） |
| pubspec.lock 前移至插件 `df98246` | 已提交（`c7c5229`） |
| 日志脱敏正则修复 | 已提交 |
| 设置备份与恢复 | 尚未真机验收 |
| 分应用代理 | UI 与持久化完成；插件 `BoxService` 的 include/exclude 调用仍被注释，未形成内核闭环（工作①同步时评估：上游 v1.1.5 未涉及此块，仍待自研排期） |
| 上游 v1.1.5 同步（工作①） | **插件侧代码与文档已完成，工作区待提交**。剩余：用户 review 后在插件仓库 commit + push master → FLsing `flutter pub upgrade flutter_sing_box` 前移 lockfile（与 `test/app_state_latency_test.dart` 存储接口适配放同一提交）→ push 触发 CI → 真机按 Upstream-Sync.md §9 验证矩阵过一遍 |
| 上游同步流程文档（工作②） | 已完成：`flutter_sing_box/docs/Upstream-Sync.md`（含 v1.1.5 同步实录附录） |

测试基线（2026-08-02 同步后）：FLsing `flutter analyze` 0 问题、37 项测试全过（advanced 13 + latency/mode/init 8 + UA 5 + widget 3 + app_update_service 8），并已用 path 覆写对 1.1.5 插件预验证 analyze/test 全绿；恢复锁定后工作区暂有 2 条 `override_on_non_overriding_member` 告警（`_MemoryStorage` 的 getDouble/setDouble 对旧锁定插件不成立），lockfile 前移后消除。插件 `flutter analyze --fatal-infos` 0 问题、Dart 测试 8 项全过（原 6 + WindowsServiceStatus 2），Kotlin 单测 7 项需 gradle 宿主环境（本机未运行，依赖 CI/AS）。

## 七、经验教训清单

1. **git 依赖锁定**：见第三节铁律，这是本项目最容易反复踩的坑。
2. **空响应体的 502 = 中间代理特征**：sing-box Clash API 自身报错必带 JSON body。`platform.http_proxy` 开启时 Android 向所有应用下发系统代理且不排除 localhost，`HttpURLConnection` 默认走 ProxySelector——**进程内访问回环服务必须 `openConnection(Proxy.NO_PROXY)`**。此前还有一层：Android 默认禁明文 HTTP，Network Security Config 已单独放行 `127.0.0.1`。
3. **模式列表不是三件套常量**：只有被 `default_mode` 或规则引用的模式才可切换；libbox 对未知模式静默忽略，插件层必须先行校验（现为大小写不敏感）。`cache_file` 会把旧模式带回来，宿主要在 Started 后主动推送偏好。
4. **sing-box 规则多字段是 AND**：曾有 `{"clash_mode":"direct","ip_is_private":true,"domain_suffix":[".cn"]}` 导致直连模式几乎匹配不到任何流量。一条规则一件事。
5. **模板改动不会自动生效于已有订阅**：模板在导入/刷新时固化进订阅配置，改模板后需让用户"更新订阅"一次。
6. **Dart raw string 正则**：`r'[^\\s]'` 是"非反斜杠非 s"而不是"非空白"，曾导致日志脱敏在 `proxies` 的 `s` 处截断输出 `<url>s/`。raw string 里写 `\S` / `\s` 单反斜杠。
7. **真机日志噪音**：`E/MESA: Failed to find VkFence` 是 Impeller Vulkan 与 Mesa/Turnip 驱动的渲染层噪音，与业务无关，`adb logcat | findstr /v MESA` 过滤；FLsing 业务错误走应用内 snackbar 与"诊断→日志"，不依赖 logcat。
8. **MMKV 多进程**：Dart/Kotlin 两侧同 ID 必须同为 `MULTI_PROCESS_MODE`；mmkv 版本两侧保持一致（当前 2.4.0，同一 Maven 坐标只打包一份原生库）。

## 八、验证与协作边界

- Agent 执行：`flutter analyze`、`flutter test`（两仓）、格式化、差异检查、文档。插件 Kotlin 单测无法本机运行时须如实说明。
- 用户执行：APK 构建（GitHub Actions `release.yml`）、真机安装、VPN/真实网络/订阅兼容验收。agent 提供简短可操作的复测清单，不代替执行。
- 提交与推送由用户决定；agent 不主动 commit/push。
- 真机待验清单：设置备份与恢复；上游 v1.1.5 同步落地后按验证矩阵完整过一遍（启动/停止/重载/网络切换/两种测速/日志流/配置校验/分应用代理评估结果）。

## 九、实现约束

- 每项设置必须明确生效时机（立即 / 重载 VPN / 下次连接 / 重启应用）之一，不能只写入不生效。
- 高风险覆写先生成候选配置过 `Libbox.checkConfig`，失败不得替换当前可用 `using_config`。
- 默认保持订阅配置，不为简化 UI 删已有能力；高级能力放二级/三级页。
- 不做多语言（文案中文）；不做自动更新检查/下载/安装（仅"设置→关于→版本"手动）；VPN bypass 不做（插件未启用 `allowBypass()`）。
- 修 bug 优先查 FLsing 本体，再查插件；插件 API 变更需同步更新 `example/guides` 与 CHANGELOG。
- 升级 libbox 前审查废弃字段（`independent_cache`、入站 `sniff` 等在更高版本已废弃，1.13.14 仍可用）。

## 十、关键文件地图

| 位置 | 职责 |
| --- | --- |
| `lib/providers/app_state.dart` | 全局状态：连接相位、模式推送与事件抑制、测速调度、订阅操作、重连、日志脱敏 |
| `lib/data/services/sing_box_service.dart` | 服务门面：分级初始化、订阅双管线导入/刷新、using_config 补丁与原子替换、UA 绑定落点 |
| `lib/data/services/app_settings.dart` | 应用设置（MMKV `flsing_app`）：模式偏好、测速、Clash API 端口/密钥、UA 列表与绑定 |
| `lib/data/services/advanced_network_config_service.dart` | DNS/TUN/路由覆写补丁与校验 |
| `lib/models/user_agents.dart` | UA 预设与校验 |
| `lib/ui/pages/settings_page.dart` | 设置全部页面（含 UA 列表管理页、日志页） |
| `lib/ui/pages/subscription_sheet.dart` | 订阅管理与添加/编辑表单（UA 下拉绑定） |
| `flutter_sing_box/lib/src/core/services/profile_service.dart` | 插件侧订阅导入（支持 `userAgent`） |
| `flutter_sing_box/android/.../FlutterSingBoxPlugin.kt` | 方法通道：启停、模式校验转发、`urlTestOutbound`（NO_PROXY）、`checkConfig` |
| `flutter_sing_box/assets/configs/singbox_config_template.json` | 订阅组装模板（clash_mode / ip_is_private / cache_file / mixed 入站） |
| `test/`（两仓） | 回归测试；改行为先看有无对应测试要同步 |
