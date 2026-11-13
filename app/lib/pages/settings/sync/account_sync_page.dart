import 'package:flutter/material.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/shell/account/account_service.dart';

/// 阶段 7 的账号骨架页面：只存本地、不联网。
class AccountSyncPage extends StatefulWidget {
  const AccountSyncPage({super.key});

  @override
  State<AccountSyncPage> createState() => _AccountSyncPageState();
}

class _AccountSyncPageState extends State<AccountSyncPage> {
  final _server = TextEditingController();
  final _account = TextEditingController();
  final _password = TextEditingController();
  bool _autoSync = false;
  bool _backgroundSync = false;
  bool _obscure = true;
  bool _ready = false;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = AccountService.instance;
    await service.init();
    if (!mounted) return;
    setState(() {
      _server.text = service.serverUrl;
      _account.text = service.username;
      _autoSync = service.autoSync;
      _backgroundSync = service.backgroundSync;
      _deviceId = service.deviceId;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _server.dispose();
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AccountService.instance.saveProfile(
      serverUrl: _server.text,
      username: _account.text,
      password: _password.text,
      autoSync: _autoSync,
      backgroundSync: _backgroundSync,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存到本地，不会联网。')),
    );
  }

  Future<void> _login() async {
    final ok = await AccountService.instance.login(
      serverUrl: _server.text,
      username: _account.text,
      password: _password.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '登录成功。'
            : '云同步尚未启用：已保存本地配置，未发起任何网络请求。'),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsDetailScaffold(
      title: const Text('账号与云同步'),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off_rounded,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('本地离线模式',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(height: 4),
                                  Text(
                                    '未登录时所有同步调用立即返回，不产生任何网络请求。'
                                    '账号信息只保存在本机。',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('账号',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _server,
                        decoration: const InputDecoration(
                          labelText: '服务器地址',
                          hintText: 'https://example.com（暂不联网）',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _account,
                        decoration: const InputDecoration(
                          labelText: '账号',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: '密码 / Token',
                          helperText: '使用 Windows DPAPI 加密后保存在 data\\account\\',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启动时自动同步'),
                        value: _autoSync,
                        onChanged: (v) => setState(() => _autoSync = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('允许后台同步'),
                        value: _backgroundSync,
                        onChanged: (v) => setState(() => _backgroundSync = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _login,
                              icon: const Icon(Icons.login_rounded),
                              label: const Text('登录（暂不联网）'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('保存到本地'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('设备 ID',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SelectableText(
                        _deviceId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'Consolas',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '阶段 7 只保留接口：SyncAdapter.pull/push 为空实现，'
                        'loggedIn 判断仅在 AccountService / SyncService 内部出现。',
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
