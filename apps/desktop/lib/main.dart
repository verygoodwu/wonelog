import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/summaries.dart';
import 'services/backend_manager.dart';
import 'services/wonelog_api.dart';

class NativeFileDrop {
  static const MethodChannel _channel = MethodChannel('wonelog/file_drop');
  static final StreamController<List<String>> _files =
      StreamController<List<String>>.broadcast();

  static Stream<List<String>> get files => _files.stream;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'filesDropped') return;
      final paths = (call.arguments as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList();
      if (paths.isNotEmpty) _files.add(paths);
    });
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NativeFileDrop.initialize();
  runApp(const WonelogClientApp());
}

class WonelogClientApp extends StatelessWidget {
  const WonelogClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wonelog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        fontFamily: 'Microsoft YaHei',
      ),
      home: const ClientShell(),
    );
  }
}

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final WonelogApi api = WonelogApi();
  late final BackendManager backend = BackendManager(api: api);
  int selectedIndex = 0;
  bool loading = true;
  bool publishing = false;
  String statusText = '正在连接本地后台...';
  String publishStep = 'idle';
  Timer? publishTimer;

  Map<String, dynamic> config = <String, dynamic>{};
  List<dynamic> cities = <dynamic>[];
  List<dynamic> links = <dynamic>[];
  List<dynamic> projects = <dynamic>[];
  List<ArticleSummary> articles = <ArticleSummary>[];
  List<VersionSummary> versions = <VersionSummary>[];

  @override
  void initState() {
    super.initState();
    refreshAll();
  }

  @override
  void dispose() {
    publishTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshAll() async {
    setState(() {
      loading = true;
      statusText = 'Connecting to Wonelog Core...';
    });

    try {
      await _loadData();
    } catch (_) {
      setState(() => statusText = 'Connecting to Wonelog Core...');
      final started = await backend.ensureRunning();
      if (!started) {
        setState(() {
          statusText =
              'Unable to start Wonelog Core. Please check release/Wonelog manager executable.';
          loading = false;
        });
        return;
      }

      try {
        await _loadData();
      } catch (error) {
        setState(() {
          statusText = 'Wonelog Core started, but data loading failed: $error';
          loading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    final results = await Future.wait<dynamic>([
      api.health(),
      api.config(),
      api.cities(),
      api.links(),
      api.projects(),
      api.articles(),
      api.versions(),
      api.publishStatus(),
    ]);

    setState(() {
      config = Map<String, dynamic>.from(results[1] as Map);
      cities = List<dynamic>.from(results[2] as List);
      links = List<dynamic>.from(results[3] as List);
      projects = List<dynamic>.from(results[4] as List);
      articles = List<ArticleSummary>.from(results[5] as List<ArticleSummary>);
      versions = List<VersionSummary>.from(results[6] as List<VersionSummary>);
      publishStep = ((results[7] as Map)['step'] ?? 'idle').toString();
      statusText = 'Wonelog Core connected';
      loading = false;
    });
  }

  Future<void> publish([String? version]) async {
    setState(() {
      publishing = true;
      publishStep = 'connecting';
      statusText = version == null || version.isEmpty
          ? '正在发布当前内容...'
          : '正在发布快照：$version';
    });

    publishTimer?.cancel();
    publishTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => pollPublishStatus(),
    );

    try {
      final result = await api.publish(version: version);
      setState(() {
        statusText = (result['message'] ?? '发布完成').toString();
        publishStep = 'done';
      });
      await refreshAll();
    } catch (error) {
      setState(() {
        statusText = '发布失败：$error';
      });
    } finally {
      publishTimer?.cancel();
      setState(() => publishing = false);
    }
  }

  Future<void> pollPublishStatus() async {
    try {
      final status = await api.publishStatus();
      setState(() {
        publishStep = (status['step'] ?? publishStep).toString();
        statusText = (status['message'] ?? statusText).toString();
      });
    } catch (_) {
      // Keep the current UI state if polling fails briefly.
    }
  }

  Future<void> syncFromServer() async {
    setState(() => statusText = '正在从服务器同步...');
    try {
      final result = await api.syncFromServer();
      setState(() => statusText = (result['message'] ?? '同步完成').toString());
      await refreshAll();
    } catch (error) {
      setState(() => statusText = '同步失败：$error');
    }
  }

  Future<void> createVersion() async {
    setState(() => statusText = '正在创建版本快照...');
    try {
      final result = await api.createVersion();
      setState(() => statusText = '已创建版本：${result['timestamp'] ?? ''}');
      await refreshAll();
    } catch (error) {
      setState(() => statusText = '创建版本失败：$error');
    }
  }

  Future<void> deleteVersion(VersionSummary version) async {
    setState(() => statusText = '正在删除版本快照：${version.timestamp}');
    try {
      await api.deleteVersion(version.timestamp);
      setState(() => statusText = '已删除版本快照：${version.timestamp}');
      await refreshAll();
    } catch (error) {
      setState(() => statusText = '删除版本失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        loading: loading,
        config: config,
        cities: cities,
        links: links,
        projects: projects,
        articles: articles,
        versions: versions,
        publishStep: publishStep,
        statusText: statusText,
        publishing: publishing,
        onRefresh: refreshAll,
        onPublish: publish,
        onSync: syncFromServer,
        onCreateVersion: createVersion,
        onNavigate: (index) => setState(() => selectedIndex = index),
      ),
      ArticlesPage(api: api, articles: articles, onRefresh: refreshAll),
      CitiesPage(
        api: api,
        cities: cities,
        onSaved: refreshAll,
        onOpenTravelTopic: () => setState(() => selectedIndex = 1),
      ),
      LinksPage(links: links, onRefresh: refreshAll),
      ProjectsPage(api: api, projects: projects, onRefresh: refreshAll),
      VersionsPage(versions: versions, onCreateVersion: createVersion),
      SettingsPage(
        api: api,
        config: config,
        statusText: statusText,
        onSaved: refreshAll,
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            minWidth: 88,
            backgroundColor: Colors.white,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF2563EB),
                child: Text(
                  'W',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard),
                label: Text('总览'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('文章'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.location_city_outlined),
                selectedIcon: Icon(Icons.location_city),
                label: Text('城市'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.link_outlined),
                selectedIcon: Icon(Icons.link),
                label: Text('友链'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.code_outlined),
                selectedIcon: Icon(Icons.code),
                label: Text('项目'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('版本'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[selectedIndex]),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.loading,
    required this.config,
    required this.cities,
    required this.links,
    required this.projects,
    required this.articles,
    required this.versions,
    required this.publishStep,
    required this.statusText,
    required this.publishing,
    required this.onRefresh,
    required this.onPublish,
    required this.onSync,
    required this.onCreateVersion,
    required this.onNavigate,
  });

  final bool loading;
  final Map<String, dynamic> config;
  final List<dynamic> cities;
  final List<dynamic> links;
  final List<dynamic> projects;
  final List<ArticleSummary> articles;
  final List<VersionSummary> versions;
  final String publishStep;
  final String statusText;
  final bool publishing;
  final VoidCallback onRefresh;
  final Future<void> Function(String? version) onPublish;
  final VoidCallback onSync;
  final VoidCallback onCreateVersion;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      title: 'Wonelog 管理台',
      subtitle: statusText,
      actions: [
        OutlinedButton.icon(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
      ],
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    MetricCard(
                      label: '项目',
                      value: '',
                      icon: Icons.code_outlined,
                      onTap: () => onNavigate(4),
                    ),
                    MetricCard(
                      label: '文章',
                      value: '${articles.length}',
                      icon: Icons.article_outlined,
                      onTap: () => onNavigate(1),
                    ),
                    MetricCard(
                      label: '城市',
                      value: '${cities.length}',
                      icon: Icons.location_city_outlined,
                      onTap: () => onNavigate(2),
                    ),
                    MetricCard(
                      label: '友链',
                      value: '${links.length}',
                      icon: Icons.link_outlined,
                      onTap: () => onNavigate(3),
                    ),
                    MetricCard(
                      label: '版本',
                      value: '${versions.length}',
                      icon: Icons.history_outlined,
                      onTap: () => onNavigate(5),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ActionPanel(
                  versions: versions,
                  publishStep: publishStep,
                  statusText: statusText,
                  publishing: publishing,
                  onPublish: onPublish,
                  onSync: onSync,
                  onCreateVersion: onCreateVersion,
                ),
                const SizedBox(height: 20),
                InfoPanel(config: config, articles: articles),
              ],
            ),
    );
  }
}

class ActionPanel extends StatefulWidget {
  const ActionPanel({
    super.key,
    required this.versions,
    required this.publishStep,
    required this.statusText,
    required this.publishing,
    required this.onPublish,
    required this.onSync,
    required this.onCreateVersion,
  });

  final List<VersionSummary> versions;
  final String publishStep;
  final String statusText;
  final bool publishing;
  final Future<void> Function(String? version) onPublish;
  final VoidCallback onSync;
  final VoidCallback onCreateVersion;

  @override
  State<ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends State<ActionPanel> {
  String? selectedVersion;

  static const List<String> _publishSteps = <String>[
    'idle',
    'connecting',
    'upload',
    'build',
    'deploy',
    'done',
  ];

  double get _progressValue {
    final step = widget.publishStep;
    if (step == 'done') return 1;
    final index = _publishSteps.indexOf(step);
    if (index <= 0) return widget.publishing ? 0.08 : 0;
    return index / (_publishSteps.length - 1);
  }

  String get _stepLabel {
    switch (widget.publishStep) {
      case 'connecting':
        return '连接服务器';
      case 'upload':
        return '上传内容与图片';
      case 'build':
        return '构建博客站点';
      case 'deploy':
        return '部署到服务器';
      case 'done':
        return '发布完成';
      case 'idle':
        return widget.publishing ? '准备发布' : '待发布';
      default:
        return widget.publishStep.isEmpty ? '待发布' : widget.publishStep;
    }
  }

  Color _progressColor(BuildContext context) {
    if (widget.statusText.contains('失败') || widget.statusText.contains('错误')) {
      return Theme.of(context).colorScheme.error;
    }
    if (widget.publishStep == 'done') return const Color(0xFF16A34A);
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedVersion =
        selectedVersion != null && selectedVersion!.isNotEmpty;
    final progress = _progressValue.clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final progressColor = _progressColor(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '发布控制',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: progressColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: widget.publishing || widget.publishStep == 'done'
                  ? progress
                  : 0,
              minHeight: 10,
              color: progressColor,
              backgroundColor: const Color(0xFFE5EAF3),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                widget.publishStep == 'done'
                    ? Icons.check_circle_outline
                    : widget.publishing
                        ? Icons.cloud_sync_outlined
                        : Icons.schedule_outlined,
                size: 18,
                color: progressColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '当前步骤：$_stepLabel · ${widget.statusText}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedVersion ?? '',
            decoration: const InputDecoration(
              labelText: '发布内容',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('当前编辑内容')),
              ...widget.versions.map(
                (version) => DropdownMenuItem(
                  value: version.timestamp,
                  child: Text(
                    '${version.timestamp} · ${version.createdAt.split('T').first}',
                  ),
                ),
              ),
            ],
            onChanged: widget.publishing
                ? null
                : (value) => setState(
                      () => selectedVersion =
                          value == null || value.isEmpty ? null : value,
                    ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: widget.publishing
                    ? null
                    : () => widget.onPublish(selectedVersion),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  widget.publishing
                      ? '发布中...'
                      : hasSelectedVersion
                          ? '发布所选快照'
                          : '一键发布',
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.publishing ? null : widget.onSync,
                icon: const Icon(Icons.sync),
                label: const Text('服务器同步'),
              ),
              OutlinedButton.icon(
                onPressed: widget.publishing ? null : widget.onCreateVersion,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('创建快照'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ArticlesPage extends StatelessWidget {
  const ArticlesPage({
    super.key,
    required this.api,
    required this.articles,
    required this.onRefresh,
  });

  final WonelogApi api;
  final List<ArticleSummary> articles;
  final Future<void> Function() onRefresh;

  Future<void> _editArticle(
    BuildContext context,
    ArticleSummary article,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ArticleEditorDialog(api: api, article: article),
    );
    if (saved == true) {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await onRefresh();
      messenger.showSnackBar(const SnackBar(content: Text('文章已保存')));
    }
  }

  Future<String?> _pickMarkdownPath() async {
    final outputFile = File(
      '${Directory.systemTemp.path}\\wonelog_markdown_pick_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    final outputPath = outputFile.path.replaceAll("'", "''");
    final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Title = '选择 Markdown 文章'
\$dialog.Filter = 'Markdown 文件 (*.md)|*.md|所有文件 (*.*)|*.*'
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Set-Content -LiteralPath '$outputPath' -Value \$dialog.FileName -Encoding UTF8
}
''';
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-STA',
      '-Command',
      script,
    ]);
    if (result.exitCode != 0 || !outputFile.existsSync()) return null;
    final selected =
        outputFile.readAsStringSync().replaceFirst('\uFEFF', '').trim();
    try {
      outputFile.deleteSync();
    } catch (_) {}
    return selected.isEmpty ? null : selected;
  }

  Future<void> _importMarkdown(BuildContext context) async {
    final selected = await _pickMarkdownPath();
    if (selected == null || selected.isEmpty || !context.mounted) return;
    await _importMarkdownPaths(context, <String>[selected], openEditor: true);
  }

  Future<void> _importMarkdownPaths(
    BuildContext context,
    List<String> paths, {
    bool openEditor = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final markdownPaths =
        paths.where((path) => path.toLowerCase().endsWith('.md')).toList();
    if (markdownPaths.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请拖入 Markdown（.md）文件')),
      );
      return;
    }

    final imported = <String>[];
    final failures = <String>[];
    for (final path in markdownPaths) {
      try {
        final result = await api.importArticle(path);
        final filename = (result['filename'] ?? '').toString();
        if (filename.isNotEmpty) imported.add(filename);
      } catch (error) {
        failures.add(error.toString());
      }
    }

    if (imported.isNotEmpty) await onRefresh();
    if (!context.mounted) return;
    if (failures.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('已导入 ${imported.length} 篇 Markdown 文章')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '成功 ${imported.length} 篇，失败 ${failures.length} 篇：${failures.first}',
          ),
        ),
      );
    }

    if (openEditor && imported.length == 1) {
      await _editArticle(
        context,
        ArticleSummary(
          filename: imported.single,
          title: imported.single.replaceFirst(RegExp(r'\.md$'), ''),
          date: '',
          description: '',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      title: '文章管理',
      subtitle: '点击文章即可编辑标题、描述、标签和正文。',
      actions: [
        FilledButton.icon(
          onPressed: () => _importMarkdown(context),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('导入 MD'),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
      ],
      child: MarkdownDropTarget(
        onFilesDropped: (paths) => _importMarkdownPaths(context, paths),
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemBuilder: (context, index) {
            final article = articles[index];
            return Panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _editArticle(context, article),
                title: Text(
                  article.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${article.filename}\n${article.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(article.date),
                    IconButton.filledTonal(
                      tooltip: '编辑文章',
                      onPressed: () => _editArticle(context, article),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: articles.length,
        ),
      ),
    );
  }
}

class MarkdownDropTarget extends StatefulWidget {
  const MarkdownDropTarget({
    super.key,
    required this.onFilesDropped,
    required this.child,
  });

  final Future<void> Function(List<String> paths) onFilesDropped;
  final Widget child;

  @override
  State<MarkdownDropTarget> createState() => _MarkdownDropTargetState();
}

class _MarkdownDropTargetState extends State<MarkdownDropTarget> {
  StreamSubscription<List<String>>? _subscription;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _subscription = NativeFileDrop.files.listen(_handleFiles);
  }

  Future<void> _handleFiles(List<String> paths) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await widget.onFilesDropped(paths);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_importing)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                border: Border.all(color: color, width: 2),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class ArticleEditorDialog extends StatefulWidget {
  const ArticleEditorDialog({
    super.key,
    required this.api,
    required this.article,
  });

  final WonelogApi api;
  final ArticleSummary article;

  @override
  State<ArticleEditorDialog> createState() => _ArticleEditorDialogState();
}

class _ArticleEditorDialogState extends State<ArticleEditorDialog> {
  final titleController = TextEditingController();
  final dateController = TextEditingController();
  final descriptionController = TextEditingController();
  final heroImageController = TextEditingController();
  final tagsController = TextEditingController();
  final bodyController = TextEditingController();

  bool loading = true;
  bool saving = false;
  bool uploadingCover = false;
  bool uploadingBodyImage = false;
  String? error;

  @override
  void initState() {
    super.initState();
    heroImageController.addListener(_refreshCoverPreview);
    _load();
  }

  @override
  void dispose() {
    titleController.dispose();
    dateController.dispose();
    descriptionController.dispose();
    heroImageController.removeListener(_refreshCoverPreview);
    heroImageController.dispose();
    tagsController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.article(widget.article.filename);
      final draft = ArticleDraft.fromMarkdown(
        widget.article.filename,
        (data['content'] ?? '').toString(),
      );
      if (!mounted) return;
      setState(() {
        titleController.text = draft.title;
        dateController.text = draft.pubDate;
        descriptionController.text = draft.description;
        heroImageController.text = draft.heroImage;
        tagsController.text = draft.tags.join(', ');
        bodyController.text = draft.body;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '加载失败：$e';
        loading = false;
      });
    }
  }

  void _refreshCoverPreview() {
    if (mounted) setState(() {});
  }

  String _imagePreviewUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('/')) return '${widget.api.baseUrl}$trimmed';
    return trimmed;
  }

  Future<String?> _pickImagePath([String title = '选择图片']) async {
    final safeTitle = title.replaceAll("'", "''");
    final outputFile = File(
      '${Directory.systemTemp.path}\\wonelog_image_pick_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    final outputPath = outputFile.path.replaceAll("'", "''");
    final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Filter = 'Images|*.png;*.jpg;*.jpeg;*.webp;*.gif'
\$dialog.Title = '$safeTitle'
if (\$dialog.ShowDialog() -eq 'OK') {
  Set-Content -LiteralPath '$outputPath' -Value \$dialog.FileName -Encoding UTF8
}
''';
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-STA',
      '-Command',
      script,
    ]);
    if (result.exitCode != 0) return null;
    if (!outputFile.existsSync()) return null;
    final selected =
        outputFile.readAsStringSync().replaceFirst('\uFEFF', '').trim();
    try {
      outputFile.deleteSync();
    } catch (_) {}
    return selected.isEmpty ? null : selected;
  }

  Future<void> _importCover() async {
    setState(() {
      uploadingCover = true;
      error = null;
    });
    try {
      final path = await _pickImagePath('选择封面图片');
      if (path == null || path.isEmpty) {
        setState(() => uploadingCover = false);
        return;
      }
      final result = await widget.api.uploadImage(path);
      final url = (result['url'] ?? '').toString();
      if (url.isEmpty) throw Exception(result['message'] ?? '上传接口没有返回 URL');
      setState(() {
        heroImageController.text = url;
        uploadingCover = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        uploadingCover = false;
        error = '封面上传失败：$e';
      });
    }
  }

  Future<void> _importBodyImage() async {
    setState(() {
      uploadingBodyImage = true;
      error = null;
    });
    try {
      final path = await _pickImagePath('选择正文图片');
      if (path == null || path.isEmpty) {
        setState(() => uploadingBodyImage = false);
        return;
      }
      final result = await widget.api.uploadImage(path);
      final url = (result['url'] ?? '').toString();
      if (url.isEmpty) throw Exception(result['message'] ?? '上传接口没有返回 URL');
      final segments = File(path).uri.pathSegments;
      final alt = segments.isEmpty ? '图片' : segments.last.split('.').first;
      final markdown = '![$alt]($url)';
      final value = bodyController.value;
      final text = value.text;
      final selection = value.selection;
      final start = selection.isValid ? selection.start : text.length;
      final end = selection.isValid ? selection.end : text.length;
      final prefix =
          start > 0 && !text.substring(0, start).endsWith('\n') ? '\n' : '';
      final suffix = end < text.length && !text.substring(end).startsWith('\n')
          ? '\n'
          : '';
      final inserted = '$prefix$markdown$suffix';
      bodyController.value = TextEditingValue(
        text: text.replaceRange(start, end, inserted),
        selection: TextSelection.collapsed(offset: start + inserted.length),
      );
      setState(() => uploadingBodyImage = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        uploadingBodyImage = false;
        error = '正文图片上传失败：$e';
      });
    }
  }

  Future<void> _save() async {
    if (titleController.text.trim().isEmpty) {
      setState(() => error = '标题不能为空');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final draft = ArticleDraft(
      filename: widget.article.filename,
      title: titleController.text.trim(),
      pubDate: dateController.text.trim(),
      description: descriptionController.text.trim(),
      heroImage: heroImageController.text.trim(),
      tags: tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      body: bodyController.text,
    );
    try {
      await widget.api.saveArticle(widget.article.filename, draft.toMarkdown());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = '保存失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      child: SizedBox(
        width: 980,
        height: 760,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '编辑文章',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.article.filename,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        saving ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (error != null) ...[
                          Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: titleController,
                                decoration: const InputDecoration(
                                  labelText: '标题',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 180,
                              child: TextField(
                                controller: dateController,
                                decoration: const InputDecoration(
                                  labelText: '日期',
                                  hintText: '2026-05-02',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: '摘要 / 描述',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: tagsController,
                                decoration: const InputDecoration(
                                  labelText: '标签',
                                  hintText: '随笔, 技术',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: heroImageController,
                                decoration: const InputDecoration(
                                  labelText: '封面图 URL',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: uploadingCover || saving
                                  ? null
                                  : _importCover,
                              icon: Icon(
                                uploadingCover
                                    ? Icons.hourglass_empty
                                    : Icons.upload_file_outlined,
                              ),
                              label: Text(uploadingCover ? '上传中' : '导入'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (heroImageController.text.trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 180,
                              width: double.infinity,
                              child: Image.network(
                                _imagePreviewUrl(heroImageController.text),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: const Text('封面预览加载失败'),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '正文 Markdown',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            OutlinedButton.icon(
                              onPressed: uploadingBodyImage || saving
                                  ? null
                                  : _importBodyImage,
                              icon: Icon(
                                uploadingBodyImage
                                    ? Icons.hourglass_empty
                                    : Icons.add_photo_alternate_outlined,
                              ),
                              label: Text(uploadingBodyImage ? '上传中' : '插入图片'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: bodyController,
                          minLines: 16,
                          maxLines: 24,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? '保存中...' : '保存文章'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CitiesPage extends StatefulWidget {
  const CitiesPage({
    super.key,
    required this.api,
    required this.cities,
    required this.onSaved,
    required this.onOpenTravelTopic,
  });

  final WonelogApi api;
  final List<dynamic> cities;
  final Future<void> Function() onSaved;
  final VoidCallback onOpenTravelTopic;

  @override
  State<CitiesPage> createState() => _CitiesPageState();
}

class _CitiesPageState extends State<CitiesPage> {
  final nameController = TextEditingController();
  final latController = TextEditingController();
  final lonController = TextEditingController();
  final commentController = TextEditingController();

  List<Map<String, dynamic>> cities = <Map<String, dynamic>>[];
  Map<String, Map<String, dynamic>> cityCoords =
      <String, Map<String, dynamic>>{};
  int? selectedIndex;
  String cityType = 'travel';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
    _loadCityCoords();
  }

  @override
  void didUpdateWidget(CitiesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cities != widget.cities) _loadCities();
  }

  @override
  void dispose() {
    nameController.dispose();
    latController.dispose();
    lonController.dispose();
    commentController.dispose();
    super.dispose();
  }

  void _loadCities() {
    cities = widget.cities
        .whereType<Map>()
        .map((city) => Map<String, dynamic>.from(city))
        .toList();
    if (selectedIndex != null && selectedIndex! >= cities.length) {
      selectedIndex = null;
    }
    if (selectedIndex != null) {
      _selectCity(selectedIndex!);
    }
  }

  Future<void> _loadCityCoords() async {
    try {
      final coords = await widget.api.cityCoords();
      if (!mounted) return;
      setState(() {
        cityCoords = coords.map(
          (key, value) =>
              MapEntry(key, Map<String, dynamic>.from(value as Map)),
        );
      });
    } catch (_) {}
  }

  String _formatCoord(dynamic value) {
    final parsed =
        value is num ? value.toDouble() : double.tryParse(value.toString());
    return parsed == null ? '' : parsed.toStringAsFixed(4);
  }

  void _applyCityCoords(String name, {bool force = false}) {
    final coord = cityCoords[name.trim()];
    if (coord == null) {
      return;
    }
    if (!force &&
        latController.text.trim().isNotEmpty &&
        lonController.text.trim().isNotEmpty) {
      return;
    }
    setState(() {
      latController.text = _formatCoord(coord['lat']);
      lonController.text = _formatCoord(coord['lon']);
    });
  }

  void _newCity() {
    setState(() {
      selectedIndex = null;
      nameController.clear();
      latController.clear();
      lonController.clear();
      commentController.clear();
      cityType = 'travel';
    });
  }

  void _selectCity(int index) {
    final city = cities[index];
    setState(() {
      selectedIndex = index;
      nameController.text = (city['name'] ?? '').toString();
      latController.text = (city['lat'] ?? '').toString();
      lonController.text = (city['lon'] ?? '').toString();
      cityType = (city['type'] ?? 'travel').toString();
      commentController.text = (city['desc'] ?? '').toString();
    });
    _applyCityCoords(nameController.text);
  }

  Future<void> _saveCity() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('城市名称不能为空')));
      return;
    }
    final city = <String, dynamic>{
      'name': name,
      'lat': double.tryParse(latController.text.trim()) ?? 0,
      'lon': double.tryParse(lonController.text.trim()) ?? 0,
      'type': cityType,
      'desc': commentController.text.trim(),
      'slug': name.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
    };
    setState(() => saving = true);
    try {
      if (selectedIndex == null) {
        cities.add(city);
      } else {
        cities[selectedIndex!] = city;
      }
      await widget.api.saveCities(cities);
      await widget.onSaved();
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('城市已保存')));
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      title: '城市管理',
      subtitle: '维护足迹城市，并为每个城市写一段评语。',
      actions: [
        OutlinedButton.icon(
          onPressed: _newCity,
          icon: const Icon(Icons.add),
          label: const Text('新增城市'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 320,
              child: ListView.separated(
                itemCount: cities.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final city = cities[index];
                  final selected = selectedIndex == index;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectCity(index),
                    child: Panel(
                      child: Row(
                        children: [
                          Icon(
                            city['type'] == 'live'
                                ? Icons.home_outlined
                                : Icons.flight_takeoff_outlined,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (city['name'] ?? '-').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  (city['desc'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Panel(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text(
                      '城市资料',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            onChanged: (value) => _applyCityCoords(value),
                            decoration: InputDecoration(
                              labelText: '城市名称',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: '按城市名补充经纬度',
                                icon: const Icon(Icons.my_location_outlined),
                                onPressed: () => _applyCityCoords(
                                  nameController.text,
                                  force: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 160,
                          child: DropdownButtonFormField<String>(
                            initialValue: cityType,
                            decoration: const InputDecoration(
                              labelText: '类型',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'travel',
                                child: Text('旅行'),
                              ),
                              DropdownMenuItem(
                                value: 'live',
                                child: Text('居住'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => cityType = value ?? 'travel'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            decoration: const InputDecoration(
                              labelText: '纬度',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: lonController,
                            decoration: const InputDecoration(
                              labelText: '经度',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: '城市评语',
                        hintText: '写下你对这个城市的印象、故事或一句话备注',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onOpenTravelTopic,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('旅游专题'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: saving ? null : _saveCity,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(saving ? '保存中...' : '保存城市'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({
    super.key,
    required this.api,
    required this.projects,
    required this.onRefresh,
  });

  final WonelogApi api;
  final List<dynamic> projects;
  final Future<void> Function() onRefresh;

  List<Map<String, dynamic>> get _items => projects
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();

  Future<void> _edit(BuildContext context, [int? index]) async {
    final items = _items;
    final initial = index == null ? <String, dynamic>{} : items[index];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProjectEditorDialog(api: api, initial: initial),
    );
    if (result == null || !context.mounted) return;
    if (index == null) {
      items.add(result);
    } else {
      items[index] = result;
    }
    await api.saveProjects(items);
    await onRefresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('项目已保存')),
      );
    }
  }

  Future<void> _delete(BuildContext context, int index) async {
    final items = _items;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定删除“${items[index]['name'] ?? '未命名项目'}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    items.removeAt(index);
    await api.saveProjects(items);
    await onRefresh();
  }

  String _previewUrl(String value) {
    if (value.startsWith('/')) return 'http://127.0.0.1:5000$value';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return AppSurface(
      title: '项目管理',
      subtitle: '展示开源项目、技术方案、交付物和关联文章。',
      actions: [
        FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('添加项目'),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
      ],
      child: items.isEmpty
          ? Center(
              child: FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('添加第一个开源项目'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final project = items[index];
                final cover = (project['cover'] ?? '').toString();
                final tech = project['tech'] is List
                    ? (project['tech'] as List).join(' · ')
                    : '';
                return Panel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 168,
                          height: 104,
                          child: cover.isEmpty
                              ? const ColoredBox(
                                  color: Color(0xFFE8EEF8),
                                  child: Icon(Icons.code, size: 36),
                                )
                              : Image.network(
                                  _previewUrl(cover),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                    color: Color(0xFFE8EEF8),
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (project['name'] ?? '未命名项目').toString(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text((project['status'] ?? '维护中').toString()),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text((project['tagline'] ?? '').toString()),
                            if (tech.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                tech,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: '编辑项目',
                        onPressed: () => _edit(context, index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '删除项目',
                        onPressed: () => _delete(context, index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class ProjectEditorDialog extends StatefulWidget {
  const ProjectEditorDialog({
    super.key,
    required this.api,
    required this.initial,
  });

  final WonelogApi api;
  final Map<String, dynamic> initial;

  @override
  State<ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<ProjectEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController taglineController;
  late final TextEditingController descriptionController;
  late final TextEditingController repositoryController;
  late final TextEditingController demoController;
  late final TextEditingController coverController;
  late final TextEditingController techController;
  late final TextEditingController highlightsController;
  late final TextEditingController outputsController;
  late final TextEditingController articleController;
  String status = '维护中';
  bool featured = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    String value(String key) => (widget.initial[key] ?? '').toString();
    String lines(String key) => widget.initial[key] is List
        ? (widget.initial[key] as List).join('\n')
        : value(key);
    nameController = TextEditingController(text: value('name'));
    taglineController = TextEditingController(text: value('tagline'));
    descriptionController = TextEditingController(text: value('description'));
    repositoryController = TextEditingController(text: value('repository'));
    demoController = TextEditingController(text: value('demo'));
    coverController = TextEditingController(text: value('cover'));
    techController = TextEditingController(
      text: widget.initial['tech'] is List
          ? (widget.initial['tech'] as List).join(', ')
          : value('tech'),
    );
    highlightsController = TextEditingController(text: lines('highlights'));
    outputsController = TextEditingController(text: lines('outputs'));
    articleController = TextEditingController(text: value('article'));
    status = value('status').isEmpty ? '维护中' : value('status');
    featured = widget.initial['featured'] != false;
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      nameController,
      taglineController,
      descriptionController,
      repositoryController,
      demoController,
      coverController,
      techController,
      highlightsController,
      outputsController,
      articleController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String?> _pickImagePath() async {
    final outputFile = File(
      '${Directory.systemTemp.path}\\wonelog_project_cover_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    final outputPath = outputFile.path.replaceAll("'", "''");
    final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Title = '选择项目封面'
\$dialog.Filter = '图片文件|*.png;*.jpg;*.jpeg;*.webp;*.gif|所有文件|*.*'
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Set-Content -LiteralPath '$outputPath' -Value \$dialog.FileName -Encoding UTF8
}
''';
    final result = await Process.run(
      'powershell.exe',
      <String>['-NoProfile', '-STA', '-Command', script],
    );
    if (result.exitCode != 0 || !outputFile.existsSync()) return null;
    final selected =
        outputFile.readAsStringSync().replaceFirst('\uFEFF', '').trim();
    try {
      outputFile.deleteSync();
    } catch (_) {}
    return selected.isEmpty ? null : selected;
  }

  Future<void> _importCover() async {
    final selected = await _pickImagePath();
    if (selected == null || !mounted) return;
    setState(() => uploading = true);
    try {
      final result = await widget.api.uploadImage(selected);
      final url = (result['url'] ?? '').toString();
      if (url.isNotEmpty) coverController.text = url;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('封面导入失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  List<String> _lines(String value) => value
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _save() {
    final name = nameController.text.trim();
    final repository = repositoryController.text.trim();
    if (name.isEmpty || repository.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写项目名称和 GitHub 仓库地址')),
      );
      return;
    }
    final existingId = (widget.initial['id'] ?? '').toString();
    Navigator.pop(context, <String, dynamic>{
      'id': existingId.isEmpty
          ? 'project-${DateTime.now().microsecondsSinceEpoch}'
          : existingId,
      'name': name,
      'tagline': taglineController.text.trim(),
      'description': descriptionController.text.trim(),
      'repository': repository,
      'demo': demoController.text.trim(),
      'cover': coverController.text.trim(),
      'status': status,
      'featured': featured,
      'tech': techController.text
          .split(RegExp(r'[,，]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'highlights': _lines(highlightsController.text),
      'outputs': _lines(outputsController.text),
      'article': articleController.text.trim(),
    });
  }

  String _previewUrl(String value) {
    if (value.startsWith('/')) return 'http://127.0.0.1:5000$value';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final cover = coverController.text.trim();
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? '添加开源项目' : '编辑开源项目'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '项目名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: taglineController,
                decoration: const InputDecoration(labelText: '一句话介绍'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '项目说明'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: repositoryController,
                      decoration: const InputDecoration(
                        labelText: 'GitHub 仓库地址',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: demoController,
                      decoration: const InputDecoration(labelText: '演示地址'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: coverController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: '封面 URL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: uploading ? null : _importCover,
                    icon: uploading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('导入封面'),
                  ),
                ],
              ),
              if (cover.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AspectRatio(
                    aspectRatio: 3 / 1,
                    child: Image.network(
                      _previewUrl(cover),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE8EEF8),
                        child: Center(child: Text('封面无法预览')),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: '项目状态'),
                      items: const [
                        DropdownMenuItem(value: '开发中', child: Text('开发中')),
                        DropdownMenuItem(value: '维护中', child: Text('维护中')),
                        DropdownMenuItem(value: '已完成', child: Text('已完成')),
                        DropdownMenuItem(value: '已归档', child: Text('已归档')),
                      ],
                      onChanged: (value) =>
                          setState(() => status = value ?? '维护中'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('精选项目'),
                      value: featured,
                      onChanged: (value) => setState(() => featured = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: techController,
                decoration: const InputDecoration(
                  labelText: '技术栈（用逗号分隔）',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: highlightsController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '核心亮点（每行一条）',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: outputsController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '交付物（每行一条）',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: articleController,
                decoration: const InputDecoration(
                  labelText: '关联文章路径或 slug（可选）',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }
}

class LinksPage extends StatelessWidget {
  const LinksPage({super.key, required this.links, required this.onRefresh});

  final List<dynamic> links;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      title: '友链管理',
      subtitle: '查看博客友链配置。',
      actions: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
      ],
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: links.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final link = links[index] is Map
              ? Map<String, dynamic>.from(links[index] as Map)
              : <String, dynamic>{};
          return Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.link_outlined)),
              title: Text(
                (link['name'] ?? '-').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${link['url'] ?? ''}\n${link['desc'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }
}

class VersionsPage extends StatelessWidget {
  const VersionsPage({
    super.key,
    required this.versions,
    required this.onCreateVersion,
  });

  final List<VersionSummary> versions;
  final VoidCallback onCreateVersion;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      title: '版本快照',
      subtitle: '保留最近 10 个内容版本。',
      actions: [
        FilledButton.icon(
          onPressed: onCreateVersion,
          icon: const Icon(Icons.add),
          label: const Text('创建快照'),
        ),
      ],
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: versions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final version = versions[index];
          return Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(
                version.timestamp,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '文章 ${version.articlesCount} · 城市 ${version.citiesCount} · 友链 ${version.linksCount}',
              ),
              trailing: Text(version.createdAt.split('T').first),
            ),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.api,
    required this.config,
    required this.statusText,
    required this.onSaved,
  });

  final WonelogApi api;
  final Map<String, dynamic> config;
  final String statusText;
  final Future<void> Function() onSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final nicknameController = TextEditingController();
  final greetingController = TextEditingController();
  final subtitleController = TextEditingController();
  final emailController = TextEditingController();
  final avatarController = TextEditingController();
  final githubController = TextEditingController();
  final rssController = TextEditingController();
  final bioController = TextEditingController();
  final footprintTitleController = TextEditingController();
  final footprintSubtitleController = TextEditingController();

  bool saving = false;
  bool uploadingAvatar = false;
  bool loadingAbout = true;
  bool footprintEnabled = true;
  Map<String, dynamic> aboutContent = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _loadConfig();
    avatarController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAbout();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) _loadConfig();
  }

  @override
  void dispose() {
    nicknameController.dispose();
    greetingController.dispose();
    subtitleController.dispose();
    emailController.dispose();
    avatarController.dispose();
    githubController.dispose();
    rssController.dispose();
    bioController.dispose();
    footprintTitleController.dispose();
    footprintSubtitleController.dispose();
    super.dispose();
  }

  void _loadConfig() {
    final config = widget.config;
    nicknameController.text = (config['nickname'] ?? '').toString();
    greetingController.text = (config['greeting'] ?? '').toString();
    subtitleController.text = (config['subtitle'] ?? '').toString();
    emailController.text = (config['email'] ?? '').toString();
    avatarController.text = (config['avatar'] ?? '').toString();
    final socials = config['socials'] is Map
        ? Map<String, dynamic>.from(config['socials'] as Map)
        : <String, dynamic>{};
    githubController.text = (socials['github'] ?? '').toString();
    rssController.text = (socials['rss'] ?? '').toString();
    final bio = config['bio'];
    bioController.text = bio is List
        ? bio.map((item) => item.toString()).join('\n')
        : (bio ?? '').toString();
  }

  Future<void> _loadAbout() async {
    try {
      final data = await widget.api.aboutContent();
      if (!mounted) return;
      final modules = data['modules'] is List
          ? List<dynamic>.from(data['modules'] as List)
          : <dynamic>[];
      final footprintModule = modules
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .firstWhere(
            (module) => module['id'] == 'footprint',
            orElse: () => <String, dynamic>{
              'id': 'footprint',
              'title': '足迹',
              'enabled': true,
            },
          );
      final footprint = data['footprint'] is Map
          ? Map<String, dynamic>.from(data['footprint'] as Map)
          : <String, dynamic>{};
      setState(() {
        aboutContent = data;
        footprintEnabled = footprintModule['enabled'] != false;
        footprintTitleController.text =
            (footprintModule['title'] ?? '足迹').toString();
        footprintSubtitleController.text =
            (footprint['subtitle'] ?? '').toString();
        loadingAbout = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingAbout = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final config = Map<String, dynamic>.from(widget.config);
    config['nickname'] = nicknameController.text.trim();
    config['greeting'] = greetingController.text.trim();
    config['subtitle'] = subtitleController.text.trim();
    config['email'] = emailController.text.trim();
    config['avatar'] = avatarController.text.trim();
    config['bio'] = bioController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    config['socials'] = <String, dynamic>{
      'github': githubController.text.trim(),
      'rss': rssController.text.trim(),
    };
    final modules = aboutContent['modules'] is List
        ? List<Map<String, dynamic>>.from(
            (aboutContent['modules'] as List).whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ),
          )
        : <Map<String, dynamic>>[];
    final index = modules.indexWhere((module) => module['id'] == 'footprint');
    final footprintModule = <String, dynamic>{
      'id': 'footprint',
      'title': footprintTitleController.text.trim().isEmpty
          ? '足迹'
          : footprintTitleController.text.trim(),
      'enabled': footprintEnabled,
    };
    if (index >= 0) {
      modules[index] = footprintModule;
    } else {
      modules.add(footprintModule);
    }
    final about = Map<String, dynamic>.from(aboutContent);
    about['modules'] = modules;
    about['footprint'] = <String, dynamic>{
      'subtitle': footprintSubtitleController.text.trim(),
    };
    try {
      await widget.api.saveConfig(config);
      await widget.api.saveAboutContent(about);
      await widget.onSaved();
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  String _avatarPreviewSource() {
    final value = avatarController.text.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:')) {
      return value;
    }
    if (value.startsWith('/')) return '${widget.api.baseUrl}$value';
    return value;
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E3F8)),
      ),
      child: const Icon(
        Icons.person_outline,
        size: 42,
        color: Color(0xFF4F67A3),
      ),
    );
  }

  Widget _avatarPreview() {
    final source = _avatarPreviewSource();
    if (source.isEmpty) return _avatarPlaceholder();
    final lower = source.toLowerCase();
    final localFile = !lower.startsWith('http://') &&
            !lower.startsWith('https://') &&
            !lower.startsWith('data:')
        ? File(source)
        : null;
    final image = localFile != null && localFile.existsSync()
        ? Image.file(localFile, fit: BoxFit.cover)
        : Image.network(
            source,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarPlaceholder(),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 104,
        height: 104,
        color: const Color(0xFFEFF6FF),
        child: image,
      ),
    );
  }

  Future<String?> _pickAvatarImage() async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前客户端暂只支持 Windows 原生图片选择')));
      return null;
    }
    final outputFile = File(
      '${Directory.systemTemp.path}\\wonelog_avatar_pick_${DateTime.now().microsecondsSinceEpoch}.txt',
    );
    final outputPath = outputFile.path.replaceAll("'", "''");
    final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dialog = New-Object System.Windows.Forms.OpenFileDialog
\$dialog.Title = '选择头像图片'
\$dialog.Filter = '图片文件 (*.png;*.jpg;*.jpeg;*.webp;*.gif)|*.png;*.jpg;*.jpeg;*.webp;*.gif|所有文件 (*.*)|*.*'
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Set-Content -LiteralPath '$outputPath' -Value \$dialog.FileName -Encoding UTF8
}
''';
    final result = await Process.run('powershell.exe', <String>[
      '-NoProfile',
      '-Sta',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      script,
    ]);
    if (result.exitCode != 0) {
      throw Exception(
        result.stderr.toString().trim().isEmpty
            ? '图片选择失败'
            : result.stderr.toString().trim(),
      );
    }
    if (!outputFile.existsSync()) return null;
    final selected =
        outputFile.readAsStringSync().replaceFirst('\uFEFF', '').trim();
    try {
      outputFile.deleteSync();
    } catch (_) {}
    return selected.isEmpty ? null : selected;
  }

  Future<void> _importAvatar() async {
    setState(() => uploadingAvatar = true);
    try {
      final selected = await _pickAvatarImage();
      if (selected == null || selected.isEmpty) return;
      final data = await widget.api.uploadImage(selected);
      final url = (data['url'] ?? '').toString();
      if (url.isEmpty) throw Exception('上传成功但没有返回图片地址');
      avatarController.text = url;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('头像已导入到图库')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('头像导入失败：$e')));
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Widget _buildPersonalInfoPanel() {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '个人信息',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nicknameController,
                  decoration: const InputDecoration(
                    labelText: '昵称',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: greetingController,
                  decoration: const InputDecoration(
                    labelText: '首页问候语',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: subtitleController,
            decoration: const InputDecoration(
              labelText: '首页副标题',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: '邮箱',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: githubController,
                  decoration: const InputDecoration(
                    labelText: 'GitHub 用户名或链接',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatarPreview(),
                  const SizedBox(height: 8),
                  Text(
                    '头像预览',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rssController,
                            decoration: const InputDecoration(
                              labelText: 'RSS 链接',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: avatarController,
                            decoration: InputDecoration(
                              labelText: '头像 URL',
                              border: const OutlineInputBorder(),
                              suffixIcon: avatarController.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '清空头像',
                                      icon: const Icon(Icons.close),
                                      onPressed: () => avatarController.clear(),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: uploadingAvatar ? null : _importAvatar,
                      icon: uploadingAvatar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(uploadingAvatar ? '导入中...' : '导入头像图片'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      title: '客户端设置',
      subtitle: '编辑站点信息、关于页文案和足迹模块。',
      actions: [
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(saving ? '保存中...' : '保存'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildPersonalInfoPanel(),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '关于页文字',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '每行会生成关于页的一条简介。',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '关于页简介',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '足迹模块',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Switch(
                      value: footprintEnabled,
                      onChanged: loadingAbout
                          ? null
                          : (value) => setState(() => footprintEnabled = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: footprintTitleController,
                        decoration: const InputDecoration(
                          labelText: '模块标题',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: footprintSubtitleController,
                        decoration: const InputDecoration(
                          labelText: '模块说明',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '连接状态：${widget.statusText}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E7EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Panel(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Icon(icon, color: const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key, required this.config, required this.articles});

  final Map<String, dynamic> config;
  final List<ArticleSummary> articles;

  @override
  Widget build(BuildContext context) {
    final latest = articles.isEmpty ? null : articles.first;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '站点概览',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Text('昵称：${config['nickname'] ?? '-'}'),
          Text('首页标题：${config['greeting'] ?? '-'}'),
          Text('最新文章：${latest?.title ?? '-'}'),
        ],
      ),
    );
  }
}
