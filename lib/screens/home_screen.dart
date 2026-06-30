import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup_codec.dart';
import '../services/backup_file.dart';
import '../theme/app_theme.dart';

String _formatCurrency(NumberFormat fmt, double value) {
  final sign = value < 0 ? '-' : '';
  return '$sign¥ ${fmt.format(value.abs())}';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  final _backupCodec = BackupCodec();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().loadAccounts();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: Consumer<AccountProvider>(
          builder: (context, provider, _) {
            if (provider.loading) {
              return Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  ),
                ),
              );
            }
            return Stack(
              children: [
                // Background texture
                _BgTexture(colors: colors),
                // Content
                FadeTransition(
                  opacity: _fadeAnim,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    slivers: [
                      _HeroNetWorth(provider: provider),
                      _SummaryRow(provider: provider),
                      _AccountSection(provider: provider),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: _AddButton(onPressed: () => _showForm(context)),
      ),
    );
  }

  // ==============================
  //  DIALOGS
  // ==============================

  Future<void> _showForm(
    BuildContext context, {
    Account? account,
    String? initialName,
    String? initialType,
    double? initialBalance,
    bool? initialIncludeInAssets,
    String? formTitle,
    int? balanceSign,
  }) async {
    final isEdit = account != null;
    final nameCtrl =
        TextEditingController(text: account?.name ?? initialName ?? '');
    final typeCtrl =
        TextEditingController(text: account?.accountType ?? initialType ?? '');
    final balanceCtrl = TextEditingController(
        text: account != null
            ? account.balance.toString()
            : initialBalance?.toString() ?? '');
    final includeInAssets =
        account?.includeInAssets ?? initialIncludeInAssets ?? true;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _FormSheet(
        isEdit: isEdit,
        nameCtrl: nameCtrl,
        typeCtrl: typeCtrl,
        balanceCtrl: balanceCtrl,
        includeInAssets: includeInAssets,
        title: isEdit ? '编辑账户' : formTitle,
        balanceSign: balanceSign,
      ),
    );

    if (result == null || !context.mounted) return;
    final name = (result['name'] as String).trim();
    final accType = (result['type'] as String).trim();
    final balance = double.tryParse(result['balance'] as String) ?? 0;
    final shouldIncludeInAssets = result['includeInAssets'] as bool;
    if (name.isEmpty || accType.isEmpty) return;

    final p = context.read<AccountProvider>();
    if (isEdit) {
      await p.updateAccount(
          id: account.id,
          name: name,
          accountType: accType,
          balance: balance,
          includeInAssets: shouldIncludeInAssets,
          note: account.note);
    } else {
      await p.addAccount(
        name: name,
        accountType: accType,
        balance: balance,
        includeInAssets: shouldIncludeInAssets,
      );
    }
  }

  Future<void> _showDataSheet(BuildContext context) async {
    final colors = context.assetBookColors;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: colors.border, width: 0.5)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHandle(colors: colors),
                const SizedBox(height: 18),
                Text(
                  '数据安全',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _ActionTile(
                  icon: Icons.lock_rounded,
                  title: '备份导出',
                  subtitle: '用密码加密保存当前数据',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _exportEncryptedBackup(context);
                  },
                ),
                _ActionTile(
                  icon: Icons.lock_open_rounded,
                  title: '备份恢复',
                  subtitle: '选择备份文件并输入密码',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _importEncryptedBackup(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportEncryptedBackup(BuildContext context) async {
    final password = await _askPassword(
      context,
      title: '设置备份密码',
      confirmLabel: '导出备份',
      helperText: '备份文件会用此密码加密保存。请妥善记录，忘记后无法恢复。',
    );
    if (password == null || !context.mounted) return;

    var progressDialogShown = false;

    void showProgress(String message) {
      if (!context.mounted) return;
      progressDialogShown = true;
      _showBlockingProgress(context, message);
    }

    void hideProgress() {
      if (!progressDialogShown || !context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressDialogShown = false;
    }

    try {
      final accounts = context.read<AccountProvider>().accounts;
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'asset_book_$stamp.assetbook';
      final destination = await chooseBackupFileDestination(fileName: fileName);
      if (destination == null || !context.mounted) return;

      showProgress('正在生成加密备份...');
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final encrypted = await _backupCodec.encodeAsync(
        accounts: accounts,
        password: password,
      );
      final saveResult = await destination.write(encrypted);
      hideProgress();
      if (!context.mounted || saveResult.cancelled) return;
      final message = saveResult.path != null
          ? '备份已导出：${saveResult.path}'
          : saveResult.selectedLocation
              ? '备份已导出：${saveResult.fileName}'
              : '备份已开始下载：${saveResult.fileName}';
      _showSnack(context, message);
      await _showInfoDialog(
        context,
        title: '导出完成',
        message: message,
      );
    } catch (error) {
      hideProgress();
      if (context.mounted) _showSnack(context, error.toString());
    }
  }

  Future<void> _importEncryptedBackup(BuildContext context) async {
    var progressDialogShown = false;

    void showProgress(String message) {
      if (!context.mounted) return;
      progressDialogShown = true;
      _showBlockingProgress(context, message);
    }

    void hideProgress() {
      if (!progressDialogShown || !context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressDialogShown = false;
    }

    try {
      final raw = await pickBackupFileText(
        onFileSelected: () {
          showProgress('正在读取备份文件...');
        },
      );
      hideProgress();
      if (raw == null || !context.mounted) return;

      final password = await _askPassword(
        context,
        title: '输入备份密码',
        confirmLabel: '读取备份',
        helperText: '请输入导出时设置的密码，验证后可恢复备份数据。',
      );
      if (password == null || !context.mounted) return;

      showProgress('正在验证密码并读取备份...');
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final accounts = await _backupCodec.decodeAsync(
          encryptedText: raw, password: password);
      hideProgress();
      if (!context.mounted) return;
      final ok = await _confirmDanger(
        context,
        title: '确认恢复备份',
        message: '将用备份中的 ${accounts.length} 个账户替换当前全部账户数据。此操作不可撤销，是否继续？',
        confirmText: '恢复',
      );
      if (ok != true || !context.mounted) return;

      await context.read<AccountProvider>().replaceAccounts(accounts);
      if (context.mounted) _showSnack(context, '已恢复 ${accounts.length} 个账户');
    } catch (error) {
      hideProgress();
      if (context.mounted) _showSnack(context, error.toString());
    }
  }

  Future<String?> _askPassword(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required String helperText,
  }) async {
    final colors = context.assetBookColors;
    final ctrl = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(helperText),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '至少 6 位',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('取消', style: TextStyle(color: colors.textMuted)),
                ),
                TextButton(
                  onPressed: () {
                    final password = ctrl.text.trim();
                    if (password.length < 6) {
                      setDialogState(() => errorText = '密码至少需要 6 位');
                      return;
                    }
                    Navigator.pop(dialogContext, password);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmDanger(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
  }) {
    final colors = context.assetBookColors;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText, style: TextStyle(color: colors.negative)),
          ),
        ],
      ),
    );
  }

  void _showBlockingProgress(BuildContext context, String message) {
    final colors = context.assetBookColors;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final colors = context.assetBookColors;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('知道了', style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ============================================================
//  BACKGROUND TEXTURE — subtle noise via a custom painter
// ============================================================
class _BgTexture extends StatelessWidget {
  final AssetBookPalette colors;

  const _BgTexture({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _NoisePainter(colors: colors),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final AssetBookPalette colors;

  const _NoisePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle radial glow in top-center
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          colors.accent.withValues(alpha: 0.10),
          colors.accent.withValues(alpha: 0),
        ],
      ).createShader(
          Rect.fromCircle(center: Offset(size.width / 2, 60), radius: 280));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}

// ============================================================
//  HERO NET WORTH — the centerpiece
// ============================================================
class _HeroNetWorth extends StatelessWidget {
  final AccountProvider provider;
  const _HeroNetWorth({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final fmt = NumberFormat('#,##0.00');
    final nw = provider.netWorth;
    final pos = nw >= 0;

    final top = MediaQuery.of(context).padding.top + 24;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, top, 24, 28),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DataButton(
                    onPressed: () {
                      final state =
                          context.findAncestorStateOfType<_HomeScreenState>();
                      state?._showDataSheet(context);
                    },
                  ),
                  const SizedBox(width: 8),
                  _ThemeButton(onPressed: () => _showThemeSheet(context)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Subtitle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: pos ? colors.positive : colors.negative,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (pos ? colors.positive : colors.negative)
                            .withValues(alpha: 0.6),
                        blurRadius: 6,
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('净资产',
                    style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4)),
              ],
            ),
            const SizedBox(height: 12),
            // Number — large, dramatic
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: nw.abs()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [colors.accent, colors.accentSoft, colors.accent],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    '${nw < 0 ? '-' : ''}¥ ${fmt.format(value)}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                      letterSpacing: 2,
                      height: 1.1,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(
                    color: (pos ? colors.positive : colors.negative)
                        .withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      pos
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: pos ? colors.positive : colors.negative),
                  const SizedBox(width: 6),
                  Text(
                    pos ? '资产状况健康' : '净资产为负',
                    style: TextStyle(
                        fontSize: 12,
                        color: pos ? colors.positive : colors.negative,
                        fontWeight: FontWeight.w600),
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

// ============================================================
//  SUMMARY ROW — four compact KPIs
// ============================================================
class _SummaryRow extends StatelessWidget {
  final AccountProvider provider;
  const _SummaryRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final fmt = NumberFormat('#,##0.00');
    final items = [
      (
        '正余额',
        provider.totalAssets,
        Icons.trending_up_rounded,
        colors.positive,
        null
      ),
      (
        '负余额',
        provider.totalLiabilities,
        Icons.trending_down_rounded,
        colors.negative,
        null
      ),
      (
        '账户数',
        provider.accountCount.toDouble(),
        Icons.wallet_rounded,
        colors.info,
        () => _showBatchAccountSheet(context, provider.accounts)
      ),
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: items.map((item) {
            final onTap = item.$5;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(item.$3, size: 20, color: item.$4),
                          const SizedBox(height: 6),
                          Text(item.$1,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                                item.$1 == '账户数'
                                    ? item.$2.toInt().toString()
                                    : _formatCurrency(fmt, item.$2),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: item.$4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

Future<void> _showBatchAccountSheet(
  BuildContext context,
  List<Account> accounts,
) async {
  final colors = context.assetBookColors;
  final selectedIds = <String>{};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final allSelected =
              accounts.isNotEmpty && selectedIds.length == accounts.length;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: colors.border, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetHandle(colors: colors),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '批量管理账户',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: accounts.isEmpty
                            ? null
                            : () {
                                setSheetState(() {
                                  if (allSelected) {
                                    selectedIds.clear();
                                  } else {
                                    selectedIds
                                      ..clear()
                                      ..addAll(accounts.map((e) => e.id));
                                  }
                                });
                              },
                        child: Text(allSelected ? '取消全选' : '全选'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: accounts.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            child: Text(
                              '暂无账户可操作',
                              style: TextStyle(color: colors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: accounts.length,
                            itemBuilder: (context, index) {
                              final account = accounts[index];
                              final selected = selectedIds.contains(account.id);
                              return Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: selected,
                                  onChanged: (value) {
                                    setSheetState(() {
                                      if (value == true) {
                                        selectedIds.add(account.id);
                                      } else {
                                        selectedIds.remove(account.id);
                                      }
                                    });
                                  },
                                  activeColor: colors.accent,
                                  checkColor: colors.background,
                                  title: Text(
                                    account.name,
                                    style: TextStyle(color: colors.textPrimary),
                                  ),
                                  subtitle: Text(
                                    account.accountType,
                                    style: TextStyle(color: colors.textMuted),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selectedIds.isEmpty
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('确认批量删除'),
                                  content: Text(
                                      '确定删除选中的 ${selectedIds.length} 个账户吗？此操作无法撤销。'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text('取消',
                                          style: TextStyle(
                                              color: colors.textMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text('删除',
                                          style: TextStyle(
                                              color: colors.negative)),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true || !context.mounted) return;
                              await context
                                  .read<AccountProvider>()
                                  .deleteAccounts(selectedIds);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text('删除已选 (${selectedIds.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.negative,
                        foregroundColor: colors.background,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _LoanShortcutStrip extends StatelessWidget {
  final AccountProvider provider;

  const _LoanShortcutStrip({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final lentTotal = provider.accounts
        .where((account) => account.accountType == '借出款')
        .fold(0.0, (sum, account) => sum + account.balance.abs());
    final borrowedTotal = provider.accounts
        .where((account) => account.accountType == '借入款')
        .fold(0.0, (sum, account) => sum + account.balance.abs());
    final fmt = NumberFormat('#,##0.00');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Row(
        children: [
          Expanded(
            child: _LoanShortcutChip(
              title: '借出',
              amount: _formatCurrency(fmt, lentTotal),
              icon: Icons.north_east_rounded,
              color: colors.positive,
              onTap: () {
                final state =
                    context.findAncestorStateOfType<_HomeScreenState>();
                state?._showForm(
                  context,
                  initialName: '',
                  initialType: '借出款',
                  initialBalance: null,
                  initialIncludeInAssets: true,
                  formTitle: '新增借出',
                  balanceSign: 1,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LoanShortcutChip(
              title: '借入',
              amount: _formatCurrency(fmt, borrowedTotal),
              icon: Icons.south_west_rounded,
              color: colors.negative,
              onTap: () {
                final state =
                    context.findAncestorStateOfType<_HomeScreenState>();
                state?._showForm(
                  context,
                  initialName: '',
                  initialType: '借入款',
                  initialBalance: null,
                  initialIncludeInAssets: true,
                  formTitle: '新增借入',
                  balanceSign: -1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanShortcutChip extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LoanShortcutChip({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    amount,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.add_rounded, color: colors.textMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  ACCOUNT SECTION
// ============================================================
class _AccountSection extends StatelessWidget {
  final AccountProvider provider;
  const _AccountSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final accounts = provider.accounts;
    if (accounts.isEmpty) return _EmptyState();

    final fmt = NumberFormat('#,##0.00');
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
        child: Row(
          children: [
            Text('账户列表',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    letterSpacing: 0.5)),
            const Spacer(),
            Text(_formatCurrency(fmt, provider.netWorth),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: provider.netWorth >= 0
                        ? colors.positive
                        : colors.negative)),
          ],
        ),
      ),
      _LoanShortcutStrip(provider: provider),
    ];

    for (final group in _groupAccountsByType(accounts)) {
      widgets.add(_AccountTypeHeader(group: group));
      for (final account in group.accounts) {
        widgets.add(_AccountCard(
          account: account,
          onTap: () {
            final state = context.findAncestorStateOfType<_HomeScreenState>();
            state?._showForm(context, account: account);
          },
        ));
      }
    }

    return SliverList(
        delegate: SliverChildBuilderDelegate(
      (_, i) => widgets[i],
      childCount: widgets.length,
    ));
  }

  List<_AccountTypeGroup> _groupAccountsByType(List<Account> accounts) {
    final grouped = <String, List<Account>>{};
    for (final account in accounts) {
      final type =
          account.accountType.trim().isEmpty ? '未分类' : account.accountType;
      grouped.putIfAbsent(type, () => <Account>[]).add(account);
    }

    final groups = grouped.entries
        .map((entry) => _AccountTypeGroup(
              type: entry.key,
              accounts: entry.value,
            ))
        .toList();

    groups.sort((a, b) {
      final aIndex = presetAccountTypes.indexOf(a.type);
      final bIndex = presetAccountTypes.indexOf(b.type);
      if (aIndex >= 0 && bIndex >= 0) return aIndex.compareTo(bIndex);
      if (aIndex >= 0) return -1;
      if (bIndex >= 0) return 1;
      return a.type.compareTo(b.type);
    });

    return groups;
  }
}

class _AccountTypeGroup {
  final String type;
  final List<Account> accounts;

  const _AccountTypeGroup({
    required this.type,
    required this.accounts,
  });

  double get total =>
      accounts.fold(0.0, (sum, account) => sum + account.balance);
}

class _AccountTypeHeader extends StatelessWidget {
  final _AccountTypeGroup group;

  const _AccountTypeHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final fmt = NumberFormat('#,##0.00');
    final totalColor = group.total >= 0 ? colors.positive : colors.negative;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 18,
            decoration: BoxDecoration(
              color: totalColor.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            group.type,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${group.accounts.length} 个',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            _formatCurrency(fmt, group.total),
            style: TextStyle(
              color: totalColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  INDIVIDUAL ACCOUNT CARD
// ============================================================
class _AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;
  const _AccountCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final fmt = NumberFormat('#,##0.00');
    final color = account.balance >= 0 ? colors.positive : colors.negative;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            onLongPress: () => _confirmDelete(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Left color bar + icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(Icons.account_balance_wallet_rounded,
                          size: 20, color: color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(account.accountType,
                            style: TextStyle(
                                fontSize: 12, color: colors.textMuted)),
                      ],
                    ),
                  ),
                  Text(_formatCurrency(fmt, account.balance),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      color: colors.border, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final colors = context.assetBookColors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('确认删除',
            style: TextStyle(color: colors.textPrimary, fontSize: 17)),
        content: Text('确定要删除「${account.name}」吗？此操作无法撤销。',
            style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: colors.negative)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AccountProvider>().deleteAccount(account.id);
    }
  }
}

// ============================================================
//  EMPTY STATE
// ============================================================
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(
                  Icons.book_rounded,
                  color: colors.textMuted,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('暂无账户',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary)),
            const SizedBox(height: 6),
            Text(
              '轻触 + 添加你的第一个账户',
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  FLOATING ACTION BUTTON
// ============================================================
class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.accent, colors.accentSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Icon(Icons.add_rounded, color: colors.background, size: 28),
        ),
      ),
    );
  }
}

class _DataButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DataButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Icon(
            Icons.ios_share_rounded,
            color: colors.accent,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ThemeButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                themeProvider.mode.icon,
                color: colors.accent,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final AssetBookPalette colors;

  const _SheetHandle({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 32,
        height: 3,
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: colors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showThemeSheet(BuildContext context) async {
  final colors = context.assetBookColors;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (sheetContext) {
      return Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: colors.border, width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '主题样式',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final mode in AppThemeMode.values)
                    _ThemeOptionTile(
                      mode: mode,
                      selected: themeProvider.mode == mode,
                      onTap: () async {
                        await context.read<ThemeProvider>().setMode(mode);
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _ThemeOptionTile extends StatelessWidget {
  final AppThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.14)
                  : colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.accent : colors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  mode.icon,
                  color: selected ? colors.accent : colors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color:
                          selected ? colors.textPrimary : colors.textSecondary,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? colors.accent : colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  BOTTOM SHEET — add / edit account
// ============================================================
class _FormSheet extends StatefulWidget {
  final bool isEdit;
  final TextEditingController nameCtrl;
  final TextEditingController typeCtrl;
  final TextEditingController balanceCtrl;
  final bool includeInAssets;
  final String? title;
  final int? balanceSign;

  const _FormSheet({
    required this.isEdit,
    required this.nameCtrl,
    required this.typeCtrl,
    required this.balanceCtrl,
    required this.includeInAssets,
    this.title,
    this.balanceSign,
  });

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  late bool _includeInAssets;
  String? _nameError;
  String? _typeError;

  @override
  void initState() {
    super.initState();
    _includeInAssets = widget.includeInAssets;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.assetBookColors;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.title ?? (widget.isEdit ? '编辑账户' : '新建账户'),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _label('名称'),
            const SizedBox(height: 6),
            _input(widget.nameCtrl, '例如：招行工资卡', errorText: _nameError),
            const SizedBox(height: 18),
            _label('类型'),
            const SizedBox(height: 6),
            _input(widget.typeCtrl, '信用卡、微信、支付宝…', errorText: _typeError),
            if (widget.typeCtrl.text.isEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presetAccountTypes.map((t) {
                  return GestureDetector(
                    onTap: () {
                      widget.typeCtrl.text = t;
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              fontSize: 12, color: colors.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 18),
            _label('余额 (¥)'),
            const SizedBox(height: 6),
            _input(widget.balanceCtrl, _balanceHint,
                keyboard: const TextInputType.numberWithOptions(
                    signed: true, decimal: true)),
            const SizedBox(height: 8),
            Text(
              _balanceHelpText,
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  value: _includeInAssets,
                  onChanged: (value) {
                    setState(() => _includeInAssets = value);
                  },
                  activeThumbColor: colors.accent,
                  title: Text(
                    '计入资产统计',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '关闭后仍保存账户，但不计入正余额、负余额和净资产。',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: colors.background,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(widget.isEdit ? '保存' : '添加账户',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.assetBookColors.textMuted,
          letterSpacing: 1));

  Widget _input(TextEditingController ctrl, String hint,
      {TextInputType keyboard = TextInputType.text, String? errorText}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      onChanged: (_) {
        if (_nameError != null || _typeError != null) {
          setState(() {
            _nameError = widget.nameCtrl.text.trim().isEmpty ? '请输入名称' : null;
            _typeError = widget.typeCtrl.text.trim().isEmpty ? '请输入类型' : null;
          });
          return;
        }
        setState(() {});
      },
      style:
          TextStyle(color: context.assetBookColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        hintStyle:
            TextStyle(color: context.assetBookColors.textMuted, fontSize: 14),
        filled: true,
        fillColor: context.assetBookColors.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: context.assetBookColors.accent, width: 1)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  void _submit() {
    final nameEmpty = widget.nameCtrl.text.trim().isEmpty;
    final typeEmpty = widget.typeCtrl.text.trim().isEmpty;
    if (nameEmpty || typeEmpty) {
      setState(() {
        _nameError = nameEmpty ? '请输入名称' : null;
        _typeError = typeEmpty ? '请输入类型' : null;
      });
      return;
    }

    final rawBalance = double.tryParse(widget.balanceCtrl.text.trim()) ?? 0;
    final balance = switch (widget.balanceSign) {
      1 => rawBalance.abs(),
      -1 => -rawBalance.abs(),
      _ => rawBalance,
    };

    Navigator.pop(context, {
      'name': widget.nameCtrl.text,
      'type': widget.typeCtrl.text,
      'balance': balance.toString(),
      'includeInAssets': _includeInAssets,
    });
  }

  String get _balanceHint {
    return switch (widget.balanceSign) {
      1 => '借出金额，例如 1000',
      -1 => '借入金额，例如 1000',
      _ => '0.00',
    };
  }

  String get _balanceHelpText {
    return switch (widget.balanceSign) {
      1 => '借出会按正余额保存，计入别人欠你的钱。',
      -1 => '借入会自动按负余额保存，计入你需要还的钱。',
      _ => '可输入负数，例如借出或负债填 -1000。',
    };
  }
}
