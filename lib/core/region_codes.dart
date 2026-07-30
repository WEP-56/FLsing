/// 从节点名称推断 ISO 地区代码，用于节点列表的国别徽章。
///
/// 订阅解析出的节点通常只有 tag（如「日本｜Tokyo-01」「HK-IPLC-01」），
/// 这里用关键词做轻量匹配，匹配不到返回 null，由调用方兜底。
library;

const _keywords = <String, List<String>>{
  'HK': ['香港', 'hong kong', 'hongkong', 'hk'],
  'TW': ['台湾', '臺灣', 'taiwan', 'tw'],
  'JP': ['日本', 'japan', 'tokyo', 'osaka', 'jp'],
  'SG': ['新加坡', '狮城', 'singapore', 'sg'],
  'US': ['美国', '美國', 'united states', 'los angeles', 'san jose', 'usa', 'us'],
  'KR': ['韩国', '韓國', 'korea', 'seoul', 'kr'],
  'GB': ['英国', '英國', 'united kingdom', 'london', 'uk', 'gb'],
  'DE': ['德国', '德國', 'germany', 'frankfurt', 'de'],
  'FR': ['法国', '法國', 'france', 'paris', 'fr'],
  'NL': ['荷兰', '荷蘭', 'netherlands', 'amsterdam', 'nl'],
  'RU': ['俄罗斯', '俄羅斯', 'russia', 'moscow', 'ru'],
  'CA': ['加拿大', 'canada', 'ca'],
  'AU': ['澳大利亚', '澳洲', 'australia', 'sydney', 'au'],
  'IN': ['印度', 'india', 'mumbai', 'in'],
  'TR': ['土耳其', 'turkey', 'tr'],
  'MY': ['马来西亚', '馬來西亞', 'malaysia', 'my'],
  'TH': ['泰国', '泰國', 'thailand', 'th'],
  'VN': ['越南', 'vietnam', 'vn'],
  'PH': ['菲律宾', '菲律賓', 'philippines', 'ph'],
  'ID': ['印尼', 'indonesia', 'id'],
  'BR': ['巴西', 'brazil', 'br'],
  'AR': ['阿根廷', 'argentina', 'ar'],
  'CN': ['中国', '中國', '大陆', 'china', 'cn'],
};

String? regionCodeFor(String name) {
  final lower = name.toLowerCase();
  // 先做包含匹配（中文与长词），两字母缩写要求独立分段避免误伤。
  for (final entry in _keywords.entries) {
    for (final keyword in entry.value) {
      if (keyword.length <= 2) {
        if (RegExp(
          '(^|[^a-z])$keyword([^a-z]|\$)',
          caseSensitive: false,
        ).hasMatch(lower)) {
          return entry.key;
        }
      } else if (lower.contains(keyword)) {
        return entry.key;
      }
    }
  }
  return null;
}
