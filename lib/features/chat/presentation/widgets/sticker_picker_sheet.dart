import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/filter_chip_pill.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/sticker_entity.dart';
import '../../domain/usecases/sticker_usecases.dart';
import '../bloc/stickers_cubit.dart';
import 'sticker_creator_sheet.dart';
import 'sticker_image.dart';

/// Opens the sticker picker and returns the sticker to send, or null if the
/// user backed out.
///
/// The caller sends it (`ChatCubit.sendSticker`) — the same division of labour
/// as the voice recorder: this route's job ends at "the user picked one".
/// Tapping a sticker sends it at once, with no confirm step, which is what the
/// design asks for and what makes a sticker feel like a reaction rather than a
/// composed message.
Future<StickerEntity?> showStickerPicker(BuildContext context) => showModalBottomSheet<StickerEntity>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => const _StickerPickerSheet(),
);

/// Which set the grid is showing. The packs are addressed by index, since
/// their ids are only known once the catalogue has loaded.
sealed class _PickerTab {
  const _PickerTab();
}

class _RecentTab extends _PickerTab {
  const _RecentTab();
}

class _MineTab extends _PickerTab {
  const _MineTab();
}

class _PackTab extends _PickerTab {
  const _PackTab(this.packId);
  final String packId;
}

class _StickerPickerSheet extends StatefulWidget {
  const _StickerPickerSheet();

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet> {
  /// The library is a singleton, held rather than provided: it outlives this
  /// sheet on purpose (reopening draws the grid it drew last time), so a
  /// `BlocProvider` here would be wrong — it would close it. The same way
  /// `ChatPage` reads `MessagesCubit`.
  final StickersCubit _stickers = sl<StickersCubit>();

  final TextEditingController _search = TextEditingController();

  /// Tab and query are the sheet's, not the cubit's: they are where the user
  /// is looking, not what the library holds, and they should start fresh on
  /// every open.
  _PickerTab _tab = const _RecentTab();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Refetched on every open — the guarantee `StickersCubit`'s own comment
    // names, and what keeps a long-lived singleton from going stale.
    unawaited(_stickers.load());
    _stickers.watchLibrary();
  }

  @override
  void dispose() {
    _stickers.releaseLibrary();
    _search.dispose();
    super.dispose();
  }

  void _choose(StickerEntity sticker) {
    // Hoisted locally so Recent is right the moment the picker reopens; the
    // server keeps the real list and the next load agrees with it.
    _stickers.markSent(sticker);
    Navigator.of(context).pop(sticker);
  }

  Future<void> _create() async {
    final created = await showStickerCreator(context);
    if (created == null || !mounted) return;
    _stickers.applySaved(created.sticker);
    if (created.send) {
      _choose(created.sticker);
      return;
    }
    // Kept, not sent: land on My stickers so the new one is on screen, and
    // drop any search that was narrowing the grid away from it.
    setState(() {
      _tab = const _MineTab();
      _query = '';
      _search.clear();
    });
    AppStatusSnackbar.showSuccess(context, title: 'Saved', message: 'Added to My stickers.');
  }

  Future<void> _manage(StickerEntity sticker) async {
    final action = await showModalBottomSheet<_StickerAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StickerActionsSheet(),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _StickerAction.send:
        _choose(sticker);
      case _StickerAction.rename:
        final name = await _promptForName(context, sticker.name);
        if (name == null || !mounted) return;
        await _stickers.rename(sticker, name);
      case _StickerAction.delete:
        final confirmed = await AppWarningDialog.show(
          context,
          title: 'Delete this sticker?',
          message: 'It leaves My stickers and Recent. Messages you have already sent keep showing it.',
          confirmLabel: 'Delete',
          icon: CupertinoIcons.delete,
        );
        if (confirmed && mounted) await _stickers.remove(sticker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    // Bounded rather than fixed: a fixed height plus the search keyboard
    // overflows a short phone, and a bounded one simply shrinks — the grid is
    // the part that gives ground.
    final available = MediaQuery.sizeOf(context).height - insets - MediaQuery.paddingOf(context).top - 32;

    return BlocConsumer<StickersCubit, StickersState>(
      bloc: _stickers,
      listenWhen: (previous, current) => previous.actionError != current.actionError && current.actionError != null,
      listener: (context, state) => AppStatusSnackbar.showError(context, message: state.actionError!),
      builder: (context, state) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + insets),
            child: Container(
              constraints: BoxConstraints(maxHeight: math.max(220, math.min(430, available))),
              decoration: BoxDecoration(
                color: colors.surf,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _SearchRow(controller: _search, onChanged: _onQuery, onCreate: state.isFull ? null : _create),
                  _TabsRow(packs: state.packs, current: _tab, enabled: _query.isEmpty, onSelect: _onTab),
                  Divider(height: 1.5, thickness: 1.5, color: colors.line),
                  Expanded(child: _body(state)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onQuery(String value) => setState(() => _query = value);

  void _onTab(_PickerTab tab) => setState(() {
    _tab = tab;
    _query = '';
    _search.clear();
  });

  Widget _body(StickersState state) {
    if (state.status == StickerLibraryStatus.loading) return const _LoadingGrid();
    if (state.status == StickerLibraryStatus.error) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: ErrorView(message: state.errorMessage ?? 'Could not load your stickers.', onRetry: _stickers.load),
      );
    }

    if (_query.trim().isNotEmpty) {
      final results = state.search(_query);
      if (results.isEmpty) {
        return _EmptyState(
          icon: CupertinoIcons.search,
          title: 'No stickers match “${_query.trim()}”',
          body: 'Try another word, or make your own.',
          actionLabel: state.isFull ? null : 'Create a sticker',
          onAction: _create,
        );
      }
      return _Grid(label: 'RESULTS', count: results.length, stickers: results, onTap: _choose, onLongPress: _manage);
    }

    switch (_tab) {
      case _RecentTab():
        if (state.recent.isEmpty) {
          return _EmptyState(
            icon: CupertinoIcons.smiley,
            title: 'Nothing sent yet',
            body: 'Stickers you send show up here, on every device.',
            actionLabel: state.isFull ? null : 'Create a sticker',
            onAction: _create,
          );
        }
        return _Grid(
          label: 'RECENTLY SENT',
          count: state.recent.length,
          stickers: state.recent,
          onTap: _choose,
          onLongPress: _manage,
          busyIds: state.busyStickerIds,
        );
      case _MineTab():
        if (state.mine.isEmpty) {
          return _EmptyState(
            icon: CupertinoIcons.sparkles,
            title: 'Make your first sticker',
            body: 'Turn any photo into a sticker and send it in any chat.',
            actionLabel: 'Create a sticker',
            onAction: _create,
          );
        }
        return _Grid(
          label: 'MY STICKERS',
          count: state.mine.length,
          stickers: state.mine,
          onTap: _choose,
          onLongPress: _manage,
          busyIds: state.busyStickerIds,
          // The Create tile leads the grid, as the design has it — and it is
          // dropped once the library is full, where it could only produce a
          // 409.
          leading: state.isFull ? null : _CreateTile(onTap: _create),
          onEndReached: state.hasMoreMine ? _stickers.loadMoreMine : null,
        );
      case _PackTab(:final packId):
        final pack = state.packs.where((p) => p.id == packId).firstOrNull;
        if (pack == null) return const _LoadingGrid();
        return _Grid(
          label: pack.name.toUpperCase(),
          count: pack.stickers.length,
          stickers: pack.stickers,
          onTap: _choose,
          // A pack's stickers cannot be renamed or deleted, so there is
          // nothing for a long press to offer.
          onLongPress: null,
        );
    }
  }
}

Future<String?> _promptForName(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final colors = AppColors.of(dialogContext);
      return AlertDialog(
        backgroundColor: colors.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: colors.line, width: 1.5),
        ),
        title: Text('Rename sticker', style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: stickerNameMaxLength,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          style: AppTextStyles.hint.copyWith(color: colors.ink),
          decoration: InputDecoration(
            hintText: 'Mochi with his stick',
            hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xs),
              borderSide: BorderSide(color: colors.line, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xs),
              borderSide: BorderSide(color: colors.yel, width: 1.5),
            ),
          ),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.subtle,
            dense: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: 'Save',
            dense: true,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

enum _StickerAction { send, rename, delete }

class _StickerActionsSheet extends StatelessWidget {
  const _StickerActionsSheet();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (action, icon, label, destructive) in const [
                (_StickerAction.send, CupertinoIcons.arrow_up_circle, 'Send', false),
                (_StickerAction.rename, CupertinoIcons.pencil, 'Rename', false),
                (_StickerAction.delete, CupertinoIcons.delete, 'Delete', true),
              ])
                InkWell(
                  onTap: () => Navigator.of(context).pop(action),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: destructive ? colors.red : colors.ink),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: destructive ? colors.red : colors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.onChanged, required this.onCreate});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Null once the library is at its 200-sticker ceiling, where Create could
  /// only end in a `409`.
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colors.surf2,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.search, size: 16, color: colors.ink3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: AppTextStyles.hint.copyWith(color: colors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search stickers',
                        hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppIconButton(icon: const Icon(CupertinoIcons.add), size: 40, onPressed: onCreate),
        ],
      ),
    );
  }
}

class _TabsRow extends StatelessWidget {
  const _TabsRow({required this.packs, required this.current, required this.enabled, required this.onSelect});

  final List<StickerPackEntity> packs;
  final _PickerTab current;

  /// A search spans every set, so while one is typed no tab is the selected
  /// one — tapping a tab is also how the search is cleared.
  final bool enabled;
  final ValueChanged<_PickerTab> onSelect;

  bool _isCurrent(_PickerTab tab) => switch ((tab, current)) {
    (_RecentTab(), _RecentTab()) => true,
    (_MineTab(), _MineTab()) => true,
    (_PackTab(packId: final a), _PackTab(packId: final b)) => a == b,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final tabs = <(_PickerTab, String)>[
      (const _RecentTab(), 'Recent'),
      (const _MineTab(), 'My stickers'),
      for (final pack in packs) (_PackTab(pack.id), pack.name),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final (tab, label) = tabs[index];
          return FilterChipPill(
            label: label,
            selected: enabled && _isCurrent(tab),
            onTap: () => onSelect(tab),
          );
        },
      ),
    );
  }
}

/// The grid itself — four across, as the design has it, with the cell size
/// falling out of the available width rather than being fixed: a hard-coded
/// tile overflows at 320dp, which is also what a 360dp phone becomes at
/// Android's larger Display size (`docs/GOTCHAS.md`).
class _Grid extends StatelessWidget {
  const _Grid({
    required this.label,
    required this.count,
    required this.stickers,
    required this.onTap,
    required this.onLongPress,
    this.busyIds = const {},
    this.leading,
    this.onEndReached,
  });

  final String label;
  final int count;
  final List<StickerEntity> stickers;
  final ValueChanged<StickerEntity> onTap;

  /// Null where nothing can be managed — a pack, or a search result set that
  /// may mix the two (the tile decides per sticker).
  final ValueChanged<StickerEntity>? onLongPress;

  final Set<String> busyIds;

  /// The Create tile, when this grid has one. Occupies the first cell.
  final Widget? leading;

  /// Pulls the next page of My stickers when the last tile is built. The cubit
  /// guards re-entry, so building the same tile twice costs nothing.
  final VoidCallback? onEndReached;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final offset = leading == null ? 0 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text('$label · $count', style: AppTextStyles.eyebrow.copyWith(color: colors.ink3)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: stickers.length + offset,
            itemBuilder: (context, index) {
              if (index < offset) return leading!;
              final sticker = stickers[index - offset];
              if (index == stickers.length + offset - 1 && onEndReached != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => onEndReached!());
              }
              return _StickerTile(
                sticker: sticker,
                busy: busyIds.contains(sticker.id),
                onTap: () => onTap(sticker),
                onLongPress: onLongPress == null || !sticker.canManage ? null : () => onLongPress!(sticker),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({required this.sticker, required this.busy, required this.onTap, required this.onLongPress});

  final StickerEntity sticker;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xs),
        onTap: busy ? null : onTap,
        onLongPress: busy ? null : onLongPress,
        child: Opacity(
          opacity: busy ? 0.5 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A framed sticker draws to its own edges, so it is inset more
              // than a cut-out, whose whitespace is part of the picture. The
              // ratios are the design's 56 : 64 inside an 80 tile.
              final side = constraints.maxWidth * (sticker.needsFrame ? 0.78 : 0.88);
              return Center(child: StickerImageView(sticker: sticker, size: side, radius: AppRadii.xs));
            },
          ),
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surf2,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xs),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.add, size: 20, color: colors.ink2),
              const SizedBox(height: 2),
              Text('CREATE', style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: 12,
      itemBuilder: (_, _) => const ShimmerBox(height: double.infinity, borderRadius: AppRadii.xs),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Null hides the button — the library is full, so the only thing it could
  /// offer is a `409`.
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = actionLabel;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Icon(icon, size: 26, color: colors.ink3),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.titleSm.copyWith(color: colors.ink)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
          if (label != null) ...[
            const SizedBox(height: 14),
            AppButton(label: label, dense: true, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
