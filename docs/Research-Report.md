# FLsing 同类项目调研报告

## 调研概述

本调研针对 Flutter + sing-box 多端代理客户端项目，重点关注安卓端实现方案。调研时间：2026-07-29。

## 调研项目

### 1. Hiddify Next

**项目地址**: https://github.com/hiddify/hiddify-next

**技术栈**:
- Flutter 3.38.5 + Dart 3.10.4
- sing-box 核心（通过 FFI 绑定）
- Riverpod 状态管理（hooks_riverpod 2.4.10）
- Drift 数据库（2.21.0）
- Material 3 设计

**项目规模**:
- Dart 文件数：332 个
- 代码量级：中大型（约 4-5 万行）
- 21 个功能模块

**核心架构**:
```
lib/
├── core/                    # 核心基础设施
│   ├── analytics/          # 分析统计
│   ├── db/                 # 数据库层（Drift）
│   ├── http_client/        # HTTP 客户端
│   ├── localization/       # 多语言
│   ├── logger/             # 日志系统
│   ├── preferences/        # 偏好设置
│   ├── router/             # 路由系统（go_router）
│   └── theme/              # 主题系统
├── features/               # 功能模块
│   ├── home/              # 主页
│   ├── profile/           # 订阅管理
│   ├── proxy/             # 节点管理
│   ├── connection/        # 连接控制
│   ├── settings/          # 设置
│   ├── stats/             # 统计信息
│   ├── log/               # 日志查看
│   ├── per_app_proxy/     # 分应用代理
│   ├── route_rules/       # 路由规则
│   └── ...                # 其他功能
└── hiddifycore/           # sing-box FFI 绑定
```

**功能特性**:
1. ✅ 多协议支持：Vless、Vmess、Reality、TUIC、Wireguard、Hysteria、SSH
2. ✅ 多订阅格式：Sing-box、V2ray、Clash、Clash meta
3. ✅ 自动选择节点（基于延迟）
4. ✅ TUN 模式
5. ✅ 分应用代理
6. ✅ 自动更新订阅
7. ✅ 深色/浅色主题
8. ✅ 多平台：Android、iOS、Windows、macOS、Linux

**安卓端实现细节**:

1. **VPN 服务**（`MainActivity.kt` + `VPNService`）:
   ```kotlin
   - 使用 FlutterFragmentActivity 作为基类
   - ServiceConnection 管理服务生命周期
   - 通过 MethodChannel 与 Flutter 通信
   - VPN 权限请求流程：prepare() -> ActivityResult -> startService
   - 通知权限处理（Android 13+）
   ```

2. **权限管理**:
   ```xml
   - INTERNET
   - FOREGROUND_SERVICE
   - FOREGROUND_SERVICE_SPECIAL_USE
   - POST_NOTIFICATIONS（Android 13+）
   - RECEIVE_BOOT_COMPLETED
   - CHANGE_NETWORK_STATE
   - REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
   - QUERY_ALL_PACKAGES（分应用代理需要）
   ```

3. **Deep Link 支持**:
   ```xml
   - hiddify://
   - v2ray:// / v2rayn:// / v2rayng://
   - clash:// / clashmeta://
   - sing-box://
   ```

4. **服务架构**:
   - VPNService：VPN 模式服务
   - ProxyService：代理模式服务
   - TileService：快速设置磁贴
   - BootReceiver：开机自启

**UI 实现**:
- 主页文件：`home_page.dart`（211 行）
- 连接按钮：`connection_button.dart`（287 行）
- 订阅卡片：`profile_tile.dart`（596 行，较复杂）
- 节点卡片：`proxy_tile.dart`（82 行）

**单文件行数**:
- 绝大多数文件 < 500 行
- 复杂组件如 `profile_tile.dart` 约 600 行
- 符合良好的代码组织实践

**优点**:
1. 架构清晰，模块化强
2. 功能完整，成熟度高
3. 多平台支持完善
4. 代码质量高，有完整的状态管理
5. sing-box FFI 集成成熟

**缺点**（对标 FLsing 目标）:
1. 功能过于复杂，不够"小白向"
2. 设置项众多，学习成本高
3. UI 专业感强，但不够极简
4. 代码量大，维护成本高

---

### 2. sing-box-for-android（官方）

**项目地址**: https://github.com/SagerNet/sing-box-for-android

**技术栈**:
- Kotlin + Jetpack Compose
- sing-box Go 库（libbox）
- Material 3 设计

**项目规模**:
- Kotlin 文件数：297 个
- 代码量级：大型
- 纯原生安卓实现

**核心架构**:
```
app/src/main/java/io/nekohasekai/sfa/
├── bg/                     # 后台服务
│   ├── BoxService.kt      # sing-box 服务核心
│   ├── VpnService.kt      # VPN 服务
│   ├── ProxyService.kt    # 代理服务
│   └── ...
├── compose/               # Compose UI
│   └── MainActivity.kt
├── database/              # 数据库
│   ├── ProfileManager.kt
│   └── Settings.kt
├── constant/              # 常量定义
└── vendor/                # 供应商特定代码
```

**关键实现**:
1. **CommandServer**：sing-box 命令服务器
2. **PlatformInterface**：平台接口桥接
3. **ServiceNotification**：前台服务通知
4. **ProfileManager**：配置管理

**优点**:
1. 官方实现，最贴近 sing-box 核心
2. 性能优秀
3. 代码质量高

**缺点**（对标 FLsing）:
1. 非 Flutter 技术栈，不能跨平台复用
2. UI 较为简陋，功能向
3. 不适合作为 FLsing 的直接参考

---

## 关键技术点总结

### 1. sing-box 集成方案

**Flutter 端集成 sing-box 的两种方式**:

#### 方案 A：FFI 绑定（Hiddify 方案）
```
Flutter (Dart)
    ↓ FFI
C 桥接层（desktop.h）
    ↓
sing-box Go 库（编译为动态库）
```

**优点**:
- 性能好，直接内存调用
- 可自定义桥接接口
- 适合深度集成

**缺点**:
- 需要编译 Go 代码为各平台动态库
- FFI 绑定代码维护成本高
- 跨平台编译复杂

#### 方案 B：插件方式（推荐给 FLsing）
```
Flutter (Dart)
    ↓ MethodChannel
flutter_sing_box 插件（Platform Channel）
    ↓ JNI (Android) / Native (iOS)
sing-box 核心
```

**优点**:
- 使用现成插件：`flutter_sing_box`
- 插件已封装 VPN、订阅、节点管理等功能
- 维护成本低

**缺点**:
- 依赖第三方插件更新
- 自定义能力有限

**FLsing 推荐**：使用 `flutter_sing_box` 插件（已在 readme 中声明）

---

### 2. 安卓 VPN 服务实现要点

#### 必要权限
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

#### VPN 服务声明
```xml
<service
    android:name=".VPNService"
    android:exported="false"
    android:foregroundServiceType="specialUse"
    android:permission="android.permission.BIND_VPN_SERVICE">
    <intent-filter>
        <action android:name="android.net.VpnService" />
    </intent-filter>
    <meta-data 
        android:name="android.net.VpnService.SUPPORTS_ALWAYS_ON"
        android:value="true"/>
</service>
```

#### 权限请求流程
```kotlin
1. VpnService.prepare(context) 检查权限
2. 如果返回 Intent，启动权限请求 Activity
3. 用户授权后，通过 ActivityResult 回调
4. 启动 VPN 服务
```

---

### 3. 数据持久化方案

#### Hiddify 方案：Drift 数据库
```dart
@DriftDatabase(tables: [Profiles, Proxies, Settings])
class AppDatabase extends _$AppDatabase {
  // SQL 查询，类型安全
}
```

**优点**:
- 类型安全的 SQL
- 自动迁移
- 支持复杂查询

**缺点**:
- 学习曲线
- 代码生成

#### FLsing 推荐：SharedPreferences + Hive
```dart
// 简单配置：SharedPreferences
final prefs = await SharedPreferences.getInstance();

// 订阅/节点数据：Hive（轻量 NoSQL）
@HiveType(typeId: 0)
class Subscription {
  @HiveField(0)
  String name;
  
  @HiveField(1)
  String url;
}
```

**原因**：
- FLsing 定位"弱配置"，数据结构简单
- 不需要复杂查询
- Hive 轻量，易用

---

### 4. 状态管理方案

#### Hiddify 方案：Riverpod
```dart
@riverpod
class ConnectionNotifier extends _$ConnectionNotifier {
  @override
  ConnectionState build() => ConnectionState.disconnected();
  
  Future<void> connect() async { ... }
}
```

#### FLsing 推荐：Provider（简化版）
```dart
class ConnectionProvider extends ChangeNotifier {
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  
  void toggleConnection() {
    _isConnected = !_isConnected;
    notifyListeners();
  }
}
```

**原因**：
- FLsing 状态简单（连接状态、当前节点、订阅列表）
- Provider 更轻量，学习成本低
- 符合"小白向"定位

---

### 5. UI 组件设计

#### 主页结构（参考 Hiddify）
```
Scaffold
  └── CustomScrollView
      ├── AppBar
      │   ├── Logo
      │   ├── Title
      │   └── 添加订阅按钮
      ├── 当前订阅卡片（ProfileTile）
      ├── 连接按钮（ConnectionButton）
      │   ├── 地球动画
      │   └── 连接状态
      └── 当前节点信息
```

#### 关键组件复杂度
| 组件 | 行数 | 复杂度 |
|------|------|--------|
| 主页 | ~200 | 中 |
| 连接按钮 | ~250 | 中高（动画） |
| 订阅卡片 | ~100 | 低 |
| 节点列表项 | ~80 | 低 |

---

## 实现建议

### 阶段 1：MVP（最小可用产品）
**目标**：导入订阅 → 选择节点 → 一键连接

**功能范围**：
1. 主页（连接按钮 + 状态显示）
2. 订阅管理（添加、删除、更新）
3. 节点列表（选择节点）
4. VPN 连接/断开

**不包含**：
- ❌ 规则配置
- ❌ 分应用代理
- ❌ 流量统计
- ❌ 日志查看
- ❌ 高级设置

**代码量预估**：
- Flutter 代码：~3000 行
- Kotlin 代码：~500 行
- 总计：~3500 行

---

### 阶段 2：完善功能
1. 节点延迟测速
2. 自动选择最快节点
3. 后台保持连接
4. 开机自启

---

### 阶段 3：体验优化
1. 地球连接动画
2. 订阅/节点抽屉优化
3. 错误提示优化
4. 深色模式完善

---

## 与 FLsing 定位对比

| 维度 | Hiddify | FLsing 目标 |
|------|---------|-------------|
| 功能数量 | 21 个模块 | ~6 个模块 |
| 代码量 | ~4-5 万行 | ~5000 行（目标）|
| 配置项 | 50+ | <10 |
| 学习成本 | 中等 | 极低 |
| UI 风格 | 功能完整 | 极简高级 |
| 目标用户 | 进阶用户 | 普通小白 |

**核心差异**：
- Hiddify 是"功能完整的瑞士军刀"
- FLsing 是"开箱即用的一键工具"

---

## 技术选型建议

### 必选
1. **核心**: `flutter_sing_box` 插件
2. **状态管理**: Provider
3. **数据库**: SharedPreferences + Hive
4. **路由**: go_router（轻量）
5. **动画**: Flutter 内置 AnimationController

### 可选
1. **图标**: FluentUI System Icons（Hiddify 使用）
2. **二维码**: mobile_scanner
3. **分享**: share_plus
4. **URL**: url_launcher

### 不需要
1. ❌ Riverpod（过度工程）
2. ❌ Drift（数据结构简单）
3. ❌ Sentry（初期不需要）
4. ❌ 分析统计（与小白定位不符）

---

## 风险与挑战

### 技术风险
1. **flutter_sing_box 插件稳定性**
   - 风险：插件可能有 bug 或不更新
   - 缓解：前期充分测试，必要时 fork 自维护

2. **VPN 权限兼容性**
   - 风险：不同安卓厂商可能有权限限制
   - 缓解：参考 Hiddify 的权限请求流程

3. **后台保活**
   - 风险：安卓厂商可能杀后台
   - 缓解：前台服务 + 白名单引导

### 产品风险
1. **功能边界控制**
   - 风险：开发过程中功能蔓延
   - 缓解：严格遵守 MVP 功能列表

2. **UI 极简与功能完整的平衡**
   - 风险：过于简化导致无法满足基本需求
   - 缓解：用户测试验证

---

## 下一步行动

### 立即执行
1. ✅ 完成同类项目调研
2. ⬜ 编写实现细节文档
3. ⬜ 编写工程约束文档
4. ⬜ 编写合作规范文档

### 开发准备
1. 搭建 Flutter 项目框架
2. 集成 `flutter_sing_box` 插件
3. 实现 MVP 主页框架
4. 安卓端权限与服务配置

---

## 参考资料

1. Hiddify Next: https://github.com/hiddify/hiddify-next
2. sing-box: https://sing-box.sagernet.org/
3. flutter_sing_box: https://pub.dev/packages/flutter_sing_box
4. Android VPN API: https://developer.android.com/reference/android/net/VpnService

---

**文档版本**: v1.0  
**更新时间**: 2026-07-29  
**调研人**: FLsing 项目组
