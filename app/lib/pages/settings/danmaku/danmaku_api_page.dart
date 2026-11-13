import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/services/storage/storage.dart';

/// DanDanPlay credentials are normally injected by CI as
/// --dart-define=DANDANAPI_APPID/KEY. Local builds can set them here.
class DanmakuApiPage extends StatefulWidget {
  const DanmakuApiPage({super.key});

  @override
  State<DanmakuApiPage> createState() => _DanmakuApiPageState();
}

class _DanmakuApiPageState extends State<DanmakuApiPage> {
  final _id = TextEditingController();
  final _key = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _id.text = GStorage.getSetting(SettingsKeys.dandanAppId);
    _key.text = GStorage.getSetting(SettingsKeys.dandanAppKey);
  }

  @override
  void dispose() {
    _id.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await GStorage.putSetting(
      SettingsKeys.dandanAppId,
      _id.text.trim(),
    );
    await GStorage.putSetting(
      SettingsKeys.dandanAppKey,
      _key.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('弹幕 API 凭证已保存，重新进入播放页后生效。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsDetailScaffold(
      title: const Text('弹幕 API 凭证'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'FSYL TV 的弹幕来自 DanDanPlay 开放接口。应用自身不内置任何账号密钥；'
                  '官方构建通过 CI 注入，自行构建/分发时可在此填入自己的 AppId 与密钥。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '未配置时弹幕请求会返回 403，播放页不会显示弹幕。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'DanDanPlay AppId',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'DanDanPlay AppKey',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://doc.dandanplay.com/open/'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('申请开放 API'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '提示：如果你使用官方发布包，密钥已经由构建流程注入，通常不需要填写这里。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
