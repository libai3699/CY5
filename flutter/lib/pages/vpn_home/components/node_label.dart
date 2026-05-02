import 'package:flutter/material.dart';

import '../models/vpn_node.dart';

/// 解析节点名称，提取 国旗 + 地区 + 编号
///
/// 截断规则（按优先级）：
///   1. `|` 前面的部分
///   2. ` - `（空格-横线-空格）前面的部分
///   3. `-` 后面跟非纯数字时截断（如 `-0.1倍`、`-高速`），
///      `-01`、`-02` 这种纯数字编号保留
class NodeLabel extends StatelessWidget {
  const NodeLabel({super.key, required this.node, this.fontSize = 14});

  final VpnNode node;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final parsed = parseNodeName(node.name);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(parsed.flag, style: TextStyle(fontSize: fontSize + 2)),
        const SizedBox(width: 6),
        Text(
          parsed.region,
          style: TextStyle(
            color: const Color(0xFF881337),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (parsed.number.isNotEmpty) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              parsed.number,
              style: TextStyle(
                color: const Color(0xFFE11D48),
                fontSize: fontSize - 2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ParsedNode {
  const ParsedNode({required this.flag, required this.region, required this.number});
  final String flag;
  final String region;
  final String number;
}

ParsedNode parseNodeName(String rawName) {
  String name = rawName;

  // Step 1: 截断 |
  final pipeIdx = name.indexOf('|');
  if (pipeIdx > 0) name = name.substring(0, pipeIdx);

  // Step 2: 截断 " - "（空格-横线-空格）
  final spaceDashIdx = name.indexOf(' - ');
  if (spaceDashIdx > 0) name = name.substring(0, spaceDashIdx);

  // Step 3: 截断 "-非纯数字" 的部分
  // 遍历所有 `-`，如果后面跟的不是纯数字就截断
  for (var i = 0; i < name.length; i++) {
    if (name[i] == '-') {
      final after = name.substring(i + 1).trim();
      // 纯数字（如 01、02）保留；其他（如 0.1倍、高速）截断
      final isPureDigits = after.isNotEmpty && RegExp(r'^\d+$').hasMatch(after);
      if (!isPureDigits && after.isNotEmpty) {
        name = name.substring(0, i);
        break;
      }
    }
  }

  name = name.trim();

  // Step 4: 提取开头的国旗 emoji（区域指示符，两个字符）
  String flag = '🌐';
  String rest = name;

  final flagMatch =
      RegExp(r'^([\u{1F1E6}-\u{1F1FF}]{2})\s*', unicode: true).firstMatch(name);
  if (flagMatch != null) {
    flag = flagMatch.group(1)!;
    rest = name.substring(flagMatch.end).trim();
  } else {
    flag = inferFlag(name);
  }

  // Step 5: 从末尾提取数字编号
  final numberMatch = RegExp(r'[-_\s]*(\d+)\s*$').firstMatch(rest);
  String number = '';
  String region = rest;

  if (numberMatch != null) {
    number = numberMatch.group(1)!.padLeft(2, '0');
    region = rest.substring(0, numberMatch.start).trim();
    region = region.replaceAll(RegExp(r'[-_\s]+$'), '').trim();
  }

  if (region.isEmpty) region = rest.trim();
  if (region.isEmpty) region = name.trim();

  return ParsedNode(flag: flag, region: region, number: number);
}

String inferFlag(String name) {
  final lower = name.toLowerCase();

  const map = <String, String>{
    'japan': '🇯🇵', 'jp': '🇯🇵', '日本': '🇯🇵',
    'korea': '🇰🇷', 'kr': '🇰🇷', '韩国': '🇰🇷',
    'hongkong': '🇭🇰', 'hong kong': '🇭🇰', 'hk': '🇭🇰', '香港': '🇭🇰',
    'taiwan': '🇹🇼', 'tw': '🇹🇼', '台湾': '🇹🇼',
    'singapore': '🇸🇬', 'sg': '🇸🇬', '新加坡': '🇸🇬',
    'usa': '🇺🇸', 'us': '🇺🇸', 'united states': '🇺🇸', '美国': '🇺🇸',
    'uk': '🇬🇧', 'united kingdom': '🇬🇧', 'britain': '🇬🇧', '英国': '🇬🇧',
    'germany': '🇩🇪', 'de': '🇩🇪', '德国': '🇩🇪',
    'france': '🇫🇷', 'fr': '🇫🇷', '法国': '🇫🇷',
    'canada': '🇨🇦', 'ca': '🇨🇦', '加拿大': '🇨🇦',
    'australia': '🇦🇺', 'au': '🇦🇺', '澳大利亚': '🇦🇺',
    'russia': '🇷🇺', 'ru': '🇷🇺', '俄罗斯': '🇷🇺',
    'india': '🇮🇳', 'in': '🇮🇳', '印度': '🇮🇳',
    'brazil': '🇧🇷', 'br': '🇧🇷', '巴西': '🇧🇷',
    'netherlands': '🇳🇱', 'nl': '🇳🇱', '荷兰': '🇳🇱',
    'turkey': '🇹🇷', 'tr': '🇹🇷', '土耳其': '🇹🇷',
    'vietnam': '🇻🇳', 'vn': '🇻🇳', '越南': '🇻🇳',
    'thailand': '🇹🇭', 'th': '🇹🇭', '泰国': '🇹🇭',
    'philippines': '🇵🇭', 'ph': '🇵🇭', '菲律宾': '🇵🇭',
    'indonesia': '🇮🇩', 'id': '🇮🇩', '印尼': '🇮🇩',
    'malaysia': '🇲🇾', 'my': '🇲🇾', '马来西亚': '🇲🇾',
    'argentina': '🇦🇷', 'ar': '🇦🇷', '阿根廷': '🇦🇷',
    'mexico': '🇲🇽', 'mx': '🇲🇽', '墨西哥': '🇲🇽',
    'uae': '🇦🇪', '阿联酋': '🇦🇪',
    'china': '🇨🇳', 'cn': '🇨🇳', '中国': '🇨🇳',
  };

  for (final entry in map.entries) {
    final kw = entry.key;
    if (kw.length <= 2) {
      if (RegExp('(?<![a-z])${RegExp.escape(kw)}(?![a-z])').hasMatch(lower)) {
        return entry.value;
      }
    } else {
      if (lower.contains(kw)) return entry.value;
    }
  }
  return '🌐';
}
