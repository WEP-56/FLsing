# FLsing 实现细节文档

## 1. 技术栈

### 核心技术
- **Flutter**: 3.24+ (稳定版)
- **Dart**: 3.5+
- **核心插件**: flutter_sing_box (https://pub.dev/packages/flutter_sing_box)

### 状态管理
- **Provider**: 轻量级状态管理
- 避免使用 Riverpod/Bloc 等重量级方案

### 数据持久化
- **SharedPreferences**: 应用配置（主题、语言、启动设置）
- **Hive**: 订阅和节点数据
- 避免使用 Drift/Sqflite

### 路由管理
- **go_router**: 声明式路由
- 简单页面可用 Navigator.push

### UI 组件
- **Material 3**: 设计系统
- **自定义动画**: AnimationController + Tween
- 避免过度依赖第三方 UI 库

---

## 2. 项目结构

```
lib/
├── main.dart                    # 入口文件
├── app/
│   ├── app.dart                # App 根组件
│   └── routes.dart             # 路由配置
├── core/
│   ├── constants/              # 常量定义
│   ├── themes/                 # 主题配置
│   ├── utils/                  # 工具函数
│   └── extensions/             # 扩展方法
├── data/
│   ├── models/                 # 数据模型
│   │   ├── subscription.dart   # 订阅模型
│   │   ├── node.dart          # 节点模型
│   │   └── connection_state.dart
│   ├── repositories/           # 数据仓库
│   │   ├── subscription_repo.dart
│   │   └── settings_repo.dart
│   └── services/               # 服务层
│       └── singbox_service.dart  # sing-box 插件封装
├── providers/                  # Provider 状态管理
│   ├── connection_provider.dart
│   ├── subscription_provider.dart
│   └── settings_provider.dart
└── ui/
    ├── pages/                  # 页面
    │   ├── home/              # 主页
    │   ├── subscriptions/     # 订阅管理
    │   ├── nodes/             # 节点列表
    │   └── settings/          # 设置
    └── widgets/               # 组件
        ├── connection_button.dart
        ├── globe_animation.dart
        ├── subscription_card.dart
        └── node_item.dart
```

---

## 3. 核心功能实现

### 3.1 sing-box 服务封装

**文件**: `lib/data/services/singbox_service.dart`

```dart
import 'package:flutter_sing_box/flutter_sing_box.dart';

class SingBoxService {
  final FlutterSingBox _singBox = FlutterSingBox();
  
  // 初始化服务
  Future<void> initialize() async {
    await _singBox.setup();
  }
  
  // 启动 VPN
  Future<bool> startVPN(String configJson) async {
    try {
      await _singBox.start(configJson);
      return true;
    } catch (e) {
      print('启动失败: $e');
      return false;
    }
  }
  
  // 停止 VPN
  Future<void> stopVPN() async {
    await _singBox.stop();
  }
  
  // 获取连接状态
  Stream<ConnectionStatus> get statusStream => _singBox.statusStream;
  
  // 节点延迟测试
  Future<int> testDelay(String nodeUrl) async {
    return await _singBox.urlTest(nodeUrl);
  }
}
```

---

### 3.2 连接状态管理

**文件**: `lib/providers/connection_provider.dart`

```dart
import 'package:flutter/foundation.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class ConnectionProvider extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _currentNode;
  Duration _connectedTime = Duration.zero;
  
  ConnectionStatus get status => _status;
  String? get currentNode => _currentNode;
  Duration get connectedTime => _connectedTime;
  
  bool get isConnected => _status == ConnectionStatus.connected;
  
  Future<void> connect(String nodeConfig) async {
    _status = ConnectionStatus.connecting;
    notifyListeners();
    
    // 调用 sing-box 服务
    final success = await _singBoxService.startVPN(nodeConfig);
    
    if (success) {
      _status = ConnectionStatus.connected;
      _currentNode = nodeConfig;
      _startTimer();
    } else {
      _status = ConnectionStatus.disconnected;
    }
    notifyListeners();
  }
  
  Future<void> disconnect() async {
    _status = ConnectionStatus.disconnecting;
    notifyListeners();
    
    await _singBoxService.stopVPN();
    
    _status = ConnectionStatus.disconnected;
    _currentNode = null;
    _stopTimer();
    notifyListeners();
  }
}
```

---

### 3.3 订阅管理

**数据模型**: `lib/data/models/subscription.dart`

```dart
import 'package:hive/hive.dart';

part 'subscription.g.dart';

@HiveType(typeId: 0)
class Subscription extends HiveObject {
  @HiveField(0)
  String id;
  
  @HiveField(1)
  String name;
  
  @HiveField(2)
  String url;
  
  @HiveField(3)
  DateTime? lastUpdate;
  
  @HiveField(4)
  int nodeCount;
  
  @HiveField(5)
  bool isActive;
  
  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.lastUpdate,
    this.nodeCount = 0,
    this.isActive = false,
  });
}
```

**订阅仓库**: `lib/data/repositories/subscription_repo.dart`

```dart
class SubscriptionRepository {
  late Box<Subscription> _box;
  
  Future<void> init() async {
    _box = await Hive.openBox<Subscription>('subscriptions');
  }
  
  // 添加订阅
  Future<void> addSubscription(Subscription sub) async {
    await _box.put(sub.id, sub);
  }
  
  // 删除订阅
  Future<void> deleteSubscription(String id) async {
    await _box.delete(id);
  }
  
  // 获取所有订阅
  List<Subscription> getAllSubscriptions() {
    return _box.values.toList();
  }
  
  // 更新订阅
  Future<void> updateSubscription(String id) async {
    final sub = _box.get(id);
    if (sub == null) return;
    
    // 下载订阅内容
    final nodes = await _downloadAndParse(sub.url);
    
    // 更新数据
    sub.lastUpdate = DateTime.now();
    sub.nodeCount = nodes.length;
    await sub.save();
  }
}
```

---

### 3.4 主页 UI 实现

**文件**: `lib/ui/pages/home/home_page.dart`

```dart
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('FLsing'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showSubscriptionDrawer(context),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsDrawer(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前订阅卡片
          CurrentSubscriptionCard(),
          
          Spacer(),
          
          // 地球连接动画
          GlobeAnimation(),
          
          SizedBox(height: 32),
          
          // 连接按钮
          ConnectionButton(),
          
          SizedBox(height: 16),
          
          // 当前节点信息
          CurrentNodeInfo(),
          
          Spacer(),
          
          // 节点抽屉触发按钮
          NodeDrawerTrigger(),
        ],
      ),
    );
  }
}
```

---

## 4. 安卓端配置

### 4.1 AndroidManifest.xml

**文件**: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- 必要权限 -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    
    <application
        android:name=".Application"
        android:label="FLsing"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        
        <!-- VPN 服务由 flutter_sing_box 插件自动注册 -->
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

### 4.2 MainActivity.kt

**文件**: `android/app/src/main/kotlin/com/flsing/app/MainActivity.kt`

```kotlin
package com.flsing.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    // flutter_sing_box 插件会自动处理 VPN 相关逻辑
    // 不需要额外代码
}
```

**说明**: flutter_sing_box 插件已封装所有 VPN 服务逻辑，无需手动实现。

---

### 4.3 build.gradle 配置

**文件**: `android/app/build.gradle`

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.flsing.app"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}

dependencies {
    // flutter_sing_box 会自动添加依赖
}
```

---

## 5. 关键流程实现

### 5.1 首次启动流程

```
启动 App
  ↓
检查是否首次启动
  ↓ 是
显示引导页（可选）
  ↓
进入主页（空状态）
  ↓
用户点击"添加订阅"
  ↓
输入订阅链接
  ↓
下载并解析订阅
  ↓
保存到 Hive
  ↓
显示节点列表
  ↓
用户选择节点
  ↓
点击连接按钮
  ↓
请求 VPN 权限
  ↓
启动 VPN 服务
  ↓
连接成功
```

### 5.2 VPN 连接流程

```dart
// 用户点击连接按钮
onPressed: () async {
  final provider = context.read<ConnectionProvider>();
  
  // 1. 检查是否已选择节点
  if (provider.currentNode == null) {
    showSnackBar('请先选择节点');
    return;
  }
  
  // 2. 检查 VPN 权限（flutter_sing_box 自动处理）
  // 3. 生成 sing-box 配置
  final config = generateSingBoxConfig(provider.currentNode);
  
  // 4. 启动连接
  await provider.connect(config);
  
  // 5. 监听状态变化
  provider.addListener(() {
    if (provider.isConnected) {
      showSnackBar('连接成功');
    } else if (provider.status == ConnectionStatus.disconnected) {
      showSnackBar('已断开连接');
    }
  });
}
```

### 5.3 订阅更新流程

```dart
Future<void> updateSubscription(String subscriptionId) async {
  // 1. 获取订阅信息
  final sub = await _repo.getSubscription(subscriptionId);
  
  // 2. 下载订阅内容
  final response = await http.get(Uri.parse(sub.url));
  
  // 3. 解析订阅格式（base64、YAML 等）
  final nodes = parseSubscription(response.body);
  
  // 4. 保存节点数据
  await _repo.saveNodes(subscriptionId, nodes);
  
  // 5. 更新订阅信息
  sub.lastUpdate = DateTime.now();
  sub.nodeCount = nodes.length;
  await _repo.updateSubscription(sub);
  
  // 6. 通知 UI 更新
  notifyListeners();
}
```

---

## 6. UI 组件详细设计

### 6.1 连接按钮（ConnectionButton）

**视觉规格**:
- 尺寸: 120x120 dp
- 圆形按钮
- 状态颜色:
  - 未连接: rgba(255, 255, 255, 0.1)
  - 连接中: 绿色渐变 + 脉冲动画
  - 已连接: #30D158（绿色）

**实现**:
```dart
class ConnectionButton extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return GestureDetector(
          onTap: () => _handleTap(provider),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColor(provider.status),
              boxShadow: provider.isConnected 
                  ? [_glowShadow()]
                  : [],
            ),
            child: Center(
              child: Icon(
                provider.isConnected ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

### 6.2 地球动画（GlobeAnimation）

**状态表现**:
- 未连接: 静止 + 暗淡
- 连接中: 旋转 + 粒子流动
- 已连接: 缓慢旋转 + 稳定光环

**实现方案**:
- 使用 Lottie 动画（推荐）
- 或自定义 Canvas 绘制

```dart
class GlobeAnimation extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return Lottie.asset(
          _getAnimationAsset(provider.status),
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
```

### 6.3 订阅卡片（SubscriptionCard）

**布局**:
```
┌─────────────────────────────────┐
│  订阅名称                  [更多] │
│  example.com/subscribe           │
│  最后更新: 2小时前  节点: 48     │
└─────────────────────────────────┘
```

**实现**:
```dart
class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subscription.name, style: TextStyle(fontSize: 16)),
              IconButton(icon: Icon(Icons.more_vert), onPressed: _showMenu),
            ],
          ),
          SizedBox(height: 8),
          Text(
            subscription.url,
            style: TextStyle(color: Colors.grey, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text('最后更新: ${_formatTime(subscription.lastUpdate)}'),
              Spacer(),
              Text('节点: ${subscription.nodeCount}'),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## 7. 数据流向图

```
用户操作
  ↓
UI 页面（Widget）
  ↓
Provider（状态管理）
  ↓
Repository（数据仓库）
  ↓ ↙ ↘
Hive    SharedPreferences    SingBoxService
(订阅/节点)  (配置)           (VPN核心)
```

---

## 8. 错误处理策略

### 8.1 网络错误

```dart
try {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return parseSubscription(response.body);
  } else {
    throw NetworkException('订阅更新失败: ${response.statusCode}');
  }
} on SocketException {
  throw NetworkException('网络连接失败，请检查网络设置');
} on TimeoutException {
  throw NetworkException('请求超时，请稍后重试');
} catch (e) {
  throw NetworkException('未知错误: $e');
}
```

### 8.2 VPN 连接错误

```dart
try {
  await _singBoxService.startVPN(config);
} on VPNPermissionDeniedException {
  showDialog('需要 VPN 权限才能连接');
} on VPNConfigException {
  showDialog('配置错误，请检查节点信息');
} on VPNStartException {
  showDialog('连接失败，请稍后重试');
}
```

### 8.3 数据解析错误

```dart
try {
  final nodes = parseSubscription(content);
  if (nodes.isEmpty) {
    throw ParseException('未找到有效节点');
  }
  return nodes;
} on FormatException {
  throw ParseException('订阅格式不正确');
} catch (e) {
  throw ParseException('解析失败: $e');
}
```

---

## 9. 性能优化

### 9.1 列表优化

```dart
// 使用 ListView.builder 而非 ListView
ListView.builder(
  itemCount: nodes.length,
  itemBuilder: (context, index) {
    return NodeItem(node: nodes[index]);
  },
);
```

### 9.2 状态更新优化

```dart
// 使用 Consumer 只刷新必要部分
Consumer<ConnectionProvider>(
  builder: (context, provider, child) {
    return Text('${provider.connectedTime}');
  },
);
```

### 9.3 图片/动画优化

```dart
// 使用 cached_network_image 缓存图片
// Lottie 动画使用 RepaintBoundary 隔离重绘
RepaintBoundary(
  child: LottieBuilder.asset('assets/globe.json'),
);
```

---

## 10. 测试策略

### 10.1 单元测试

**测试内容**:
- 订阅解析逻辑
- 配置生成逻辑
- 数据模型序列化

**示例**:
```dart
test('解析 base64 订阅', () {
  final content = 'vmess://...';
  final nodes = parseSubscription(content);
  expect(nodes.length, greaterThan(0));
  expect(nodes[0].name, isNotEmpty);
});
```

### 10.2 集成测试

**测试流程**:
1. 添加订阅 → 验证保存
2. 更新订阅 → 验证节点数据
3. 选择节点 → 启动连接 → 验证状态

### 10.3 手动测试清单

**连接测试**:
- [ ] VPN 权限请求
- [ ] 连接成功
- [ ] 断开连接
- [ ] 切换节点
- [ ] 后台保持连接

**订阅测试**:
- [ ] 添加订阅
- [ ] 更新订阅
- [ ] 删除订阅
- [ ] 订阅链接格式兼容性

**UI 测试**:
- [ ] 深色模式
- [ ] 动画流畅度
- [ ] 抽屉交互
- [ ] 长文本显示

---

## 11. 依赖清单

### 必选依赖

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 核心
  flutter_sing_box: ^latest
  
  # 状态管理
  provider: ^6.1.0
  
  # 数据持久化
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.0
  
  # 网络
  http: ^1.1.0
  dio: ^5.3.0
  
  # 路由
  go_router: ^13.0.0
  
  # UI
  lottie: ^3.0.0
  
  # 工具
  uuid: ^4.0.0
  intl: ^0.18.0
  url_launcher: ^6.2.0

dev_dependencies:
  # 代码生成
  hive_generator: ^2.0.0
  build_runner: ^2.4.0
  
  # 测试
  flutter_test:
    sdk: flutter
```

### 可选依赖

```yaml
dependencies:
  # 二维码扫描
  mobile_scanner: ^4.0.0
  
  # 分享
  share_plus: ^7.2.0
  
  # 图标
  fluentui_system_icons: ^1.1.0
```

---

## 12. 开发环境要求

### 工具版本
- Flutter: 3.24+
- Dart: 3.5+
- Android Studio: 2023.1+
- Gradle: 8.0+
- Kotlin: 1.9+

### 安卓 SDK
- minSdkVersion: 21 (Android 5.0)
- targetSdkVersion: 34 (Android 14)
- compileSdkVersion: 34

---

## 13. 参考 flutter_sing_box 文档

**插件地址**: https://pub.dev/packages/flutter_sing_box

**核心 API**:
```dart
// 初始化
await FlutterSingBox.setup();

// 启动
await FlutterSingBox.start(configJson);

// 停止
await FlutterSingBox.stop();

// 状态监听
FlutterSingBox.statusStream.listen((status) {
  print('VPN 状态: $status');
});

// 延迟测试
final delay = await FlutterSingBox.urlTest(nodeUrl);
```

**注意事项**:
1. 插件会自动处理 VPN 权限请求
2. 插件会自动注册 VPN 服务
3. 配置格式必须符合 sing-box 规范

---

**文档版本**: v1.0  
**更新时间**: 2026-07-29  
**作者**: FLsing 项目组

