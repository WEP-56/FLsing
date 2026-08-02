/// 订阅请求的 User-Agent 预设。
///
/// 订阅服务器通常按 UA 决定返回格式：含 clash 的多返回 Clash YAML，含
/// sing-box 的返回 sing-box JSON，其余多为 Base64 分享链接。版本号只是
/// 标识，不要求与真实客户端保持同步。
class UserAgentPreset {
  const UserAgentPreset(this.label, this.value);

  final String label;
  final String value;
}

const kUserAgentPresets = [
  UserAgentPreset('Clash Meta（mihomo）', 'clash.meta/1.19.13'),
  UserAgentPreset('Clash Verge', 'clash-verge/v2.4.7'),
  UserAgentPreset('Clash for Android', 'ClashMetaForAndroid/2.11.27.Meta'),
  UserAgentPreset('sing-box（SFA）', 'SFA/1.13.14 (sing-box 1.13.14)'),
  UserAgentPreset('v2rayN', 'v2rayN/7.12.5'),
  UserAgentPreset('v2rayNG', 'v2rayNG/1.10.16'),
  UserAgentPreset('Shadowrocket', 'Shadowrocket/2.2.65'),
  UserAgentPreset(
    'Chrome 浏览器',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  ),
];

/// HTTP 头的值只允许可见 ASCII（含空格），并限制长度防误粘贴。
bool isValidUserAgentValue(String value) =>
    value.isNotEmpty &&
    value.length <= 512 &&
    RegExp(r'^[\x20-\x7E]+$').hasMatch(value);
