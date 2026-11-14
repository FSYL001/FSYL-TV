import 'package:flutter/material.dart';

import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/bean/widget/content_section.dart';
import 'package:kazumi/pages/about/about_widgets.dart';
import 'package:kazumi/request/config/api_endpoints.dart';
import 'package:kazumi/shell/app_version.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.onCheckUpdate});

  final Future<bool> Function() onCheckUpdate;

  @override
  Widget build(BuildContext context) => SettingsDetailScaffold(
        title: const Text('关于'),
        body: AboutContent(
          children: [
            _ProjectHeader(onCheckUpdate: onCheckUpdate),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'FSYL TV 基于 Kazumi（GPL-3.0）与 MoonTV（MIT）修改而来，'
                '整体以 GPL-3.0 公开发布。所有上游版权声明、LICENSE 与第三方许可文本均予保留。',
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              final sections = [
                ContentSection.group(
                  title: '上游项目',
                  children: [
                    const AboutLinkTile(
                      icon: Icons.code_rounded,
                      title: 'Kazumi 源代码（GPL-3.0）',
                      subtitle: 'https://github.com/Predidit/Kazumi',
                      url: 'https://github.com/Predidit/Kazumi',
                    ),
                    const AboutLinkTile(
                      icon: Icons.movie_filter_outlined,
                      title: 'MoonTV 源代码（MIT）',
                      subtitle: 'https://github.com/samqin123/MoonTV',
                      url: 'https://github.com/samqin123/MoonTV',
                    ),
                    AboutLinkTile(
                      icon: Icons.folder_zip_outlined,
                      title: 'FSYL TV 完整源码',
                      subtitle: 'GitHub 仓库：${AppVersion.githubRepository}',
                      url: AppVersion.githubRepository,
                    ),
                    const AboutLinkTile(
                      icon: Icons.cloud_outlined,
                      title: 'Gitee 镜像',
                      subtitle: 'https://gitee.com/FSYL001/FSYL-TV',
                      url: 'https://gitee.com/FSYL001/FSYL-TV',
                    ),
                    const AboutLinkTile(
                      icon: Icons.balance_rounded,
                      title: 'GPL-3.0 许可证',
                      subtitle: 'LICENSE（安装目录内保留原文）',
                      url: 'https://www.gnu.org/licenses/gpl-3.0.txt',
                    ),
                    const AboutLinkTile(
                      icon: Icons.description_outlined,
                      title: '第三方许可与声明',
                      subtitle: 'THIRD-PARTY-NOTICES.md / LICENSE-MOONTV-MIT',
                      url:
                          'https://github.com/samqin123/MoonTV/blob/main/LICENSE',
                    ),
                  ],
                ),
                ContentSection.group(
                  title: '上游链接与致谢',
                  children: const [
                    AboutLinkTile(
                      icon: Icons.language_rounded,
                      title: '上游 Kazumi 项目主页',
                      url: 'https://github.com/Predidit/Kazumi',
                    ),
                    AboutLinkTile(
                      icon: Icons.bug_report_rounded,
                      title: '上游 Kazumi 问题反馈',
                      url: 'https://github.com/Predidit/Kazumi/issues',
                    ),
                    AboutLinkTile.route(
                      icon: Icons.favorite_outline_rounded,
                      title: '致谢',
                      route: '/settings/about/credits',
                    ),
                  ],
                ),
              ];
              if (constraints.maxWidth >= 640 &&
                  MediaQuery.textScalerOf(context).scale(14) < 21) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sections[0]),
                    const SizedBox(width: 16),
                    Expanded(child: sections[1]),
                  ],
                );
              }
              return Column(
                children: [
                  sections[0],
                  const SizedBox(height: 24),
                  sections[1]
                ],
              );
            }),
          ],
        ),
      );
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({required this.onCheckUpdate});

  final Future<bool> Function() onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'FSYL TV',
              style: theme.textTheme.displayMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'FSYL TV ${AppVersion.current} · 上游 Kazumi ${ApiEndpoints.version}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '本地单窗口影视客户端 · 动漫基于 Kazumi，影视基于 MoonTV',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CheckUpdateButton(onCheckUpdate: onCheckUpdate),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => openAboutLink(
                  context,
                  '${AppVersion.githubRepository}/releases',
                ),
                child: const Text('FSYL TV 更新日志'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
