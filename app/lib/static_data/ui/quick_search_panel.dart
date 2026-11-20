import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';
import 'package:kaname_static_data_bundle/kaname_static_data_bundle.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shell/ui/scrim.dart';
import '../logic/quick_search.dart';
import '../logic/static_data_state.dart';
import 'quick_search_keys.dart';

/// The panel under the search field: the matches, or the reason there are
/// none (design D21, D22).
///
/// A floating Lifted Card with the Float shadow. [state] decides what it
/// shows; [active] is the index of the highlighted result, or -1 for none.
/// With [fullWidth] it spans the window, so only its lower corners are
/// rounded. It paints nothing for [SearchBlank]: the caller shows no panel
/// then.
class QuickSearchPanel extends StatefulWidget {
  /// Creates the panel for [state].
  const QuickSearchPanel({
    required this.state,
    this.active = -1,
    this.onHover,
    this.fullWidth = false,
    super.key,
  });

  /// What the search shows.
  final QuickSearchState state;

  /// The highlighted result's index, or -1 when none is highlighted.
  final int active;

  /// Called with a result's index when the pointer moves onto it.
  final ValueChanged<int>? onHover;

  /// Whether the panel spans the window's width.
  final bool fullWidth;

  /// The height of one result row.
  static const double rowHeight = 32;

  @override
  State<QuickSearchPanel> createState() => _QuickSearchPanelState();
}

class _QuickSearchPanelState extends State<QuickSearchPanel> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuickSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active && widget.active >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  /// Scrolls, without animation, so the highlighted row is in view.
  void _reveal() {
    if (!mounted || !_scroll.hasClients) return;
    final top = widget.active * QuickSearchPanel.rowHeight;
    final bottom = top + QuickSearchPanel.rowHeight;
    final position = _scroll.position;
    if (top < position.pixels) {
      _scroll.jumpTo(top);
    } else if (bottom > position.pixels + position.viewportDimension) {
      _scroll.jumpTo(bottom - position.viewportDimension);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final l10n = AppLocalizations.of(context);
    final radius = widget.fullWidth
        ? const BorderRadius.vertical(bottom: Radius.circular(EmberRadius.l))
        : BorderRadius.circular(EmberRadius.l);
    // The panel floats over the page, so it also takes the window's own
    // keyboard inset: a scaffold that drops the inset for its body must not
    // hide the keyboard from it. The media query rebuilds it as either
    // changes.
    final media = MediaQuery.of(context);
    final keyboard = max(
      media.viewInsets.bottom,
      MediaQueryData.fromView(View.of(context)).viewInsets.bottom,
    );
    final maxHeight = (media.size.height - keyboard - 120).clamp(
      QuickSearchPanel.rowHeight * 3,
      QuickSearchPanel.rowHeight * 11,
    );
    final content = switch (widget.state) {
      SearchBlank() => const SizedBox.shrink(),
      SearchNotLoaded(:final reason) => _NotLoaded(
        key: QuickSearchKeys.notLoaded,
        message: _reasonMessage(l10n, reason),
      ),
      SearchFound(:final results, :final notice) => _Found(
        results: results,
        notice: notice,
        active: widget.active,
        onHover: widget.onHover,
        controller: _scroll,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: floatShadow(context)),
      child: DecoratedBox(
        key: QuickSearchKeys.panel,
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: radius,
          border: Border.all(color: colors.hairline),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The localised message for why the app holds no bundle (design D21).
String _reasonMessage(AppLocalizations l10n, NoBundleReason reason) =>
    switch (reason) {
      Starting() => l10n.searchReasonStarting,
      Downloading() => l10n.searchReasonDownloading,
      NoServerConfigured() => l10n.searchReasonNoServer,
      ServerUnreachable() => l10n.searchReasonUnreachable,
      ServerHasNoBundle() => l10n.searchReasonServerHasNoBundle,
      BundleRefusedReason() => l10n.searchReasonRefused,
      AppUpdateNeededReason() => l10n.searchReasonAppUpdate,
    };

class _NotLoaded extends StatelessWidget {
  const _NotLoaded({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.all(EmberSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.searchNotLoaded,
              style: EmberType.uiHeading.copyWith(color: colors.ink),
            ),
            const SizedBox(height: EmberSpace.xs),
            Text(
              message,
              style: EmberType.body.copyWith(color: colors.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Found extends StatelessWidget {
  const _Found({
    required this.results,
    required this.notice,
    required this.active,
    required this.onHover,
    required this.controller,
  });

  final SearchResults results;
  final BundleNotice? notice;
  final int active;
  final ValueChanged<int>? onHover;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final l10n = AppLocalizations.of(context);
    final hits = results.hits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice case final notice?) _Notice(notice: notice),
        // Announces the count to screen readers when it changes.
        Semantics(
          liveRegion: true,
          label: l10n.searchResultCount(hits.length),
          child: const SizedBox.shrink(),
        ),
        if (hits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(EmberSpace.md),
            child: Text(
              l10n.searchNoMatches,
              style: EmberType.body.copyWith(color: colors.inkSecondary),
            ),
          )
        else
          Flexible(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: l10n.searchResults,
              child: ListView.builder(
                controller: controller,
                shrinkWrap: true,
                padding: const EdgeInsets.all(6),
                itemExtent: QuickSearchPanel.rowHeight,
                itemCount: hits.length,
                itemBuilder: (context, index) => _ResultRow(
                  key: QuickSearchKeys.result(index),
                  hit: hits[index],
                  active: index == active,
                  onHover: onHover == null ? null : () => onHover!(index),
                ),
              ),
            ),
          ),
        if (results.more)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EmberSpace.md,
              0,
              EmberSpace.md,
              EmberSpace.sm,
            ),
            child: Text(
              l10n.searchMoreMatches,
              style: EmberType.label.copyWith(color: colors.inkTertiary),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.notice});

  final BundleNotice notice;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final l10n = AppLocalizations.of(context);
    final message = switch (notice) {
      AppUpdateNeeded() => l10n.searchNoticeAppUpdate,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: DecoratedBox(
        key: QuickSearchKeys.notice,
        decoration: BoxDecoration(
          color: colors.warnBg,
          borderRadius: BorderRadius.circular(EmberRadius.l),
          border: Border.all(color: colors.warnLine),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.info_outline,
                  size: EmberSize.icon,
                  color: colors.warnStrong,
                ),
              ),
              const SizedBox(width: EmberSpace.sm),
              Expanded(
                child: Text(
                  message,
                  style: EmberType.body.copyWith(
                    fontSize: 12.5,
                    color: colors.warnInk,
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

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.hit,
    required this.active,
    required this.onHover,
    super.key,
  });

  final SearchHit hit;
  final bool active;
  final VoidCallback? onHover;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final l10n = AppLocalizations.of(context);
    final kind = switch (hit.kind) {
      SearchKind.type => l10n.searchKindType,
      SearchKind.solarSystem => l10n.searchKindSolarSystem,
    };
    final name = hit.name ?? l10n.searchUnnamed(hit.id);
    return MergeSemantics(
      child: Semantics(
        selected: active,
        child: MouseRegion(
          onEnter: onHover == null ? null : (_) => onHover!(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? colors.hover : null,
              borderRadius: BorderRadius.circular(EmberRadius.m),
            ),
            child: Row(
              children: [
                // The Ember edge marks the highlighted row, as the current
                // card's does (DESIGN.md, Containers).
                Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? colors.accent : null,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  flex: 3,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EmberType.body.copyWith(color: colors.ink),
                  ),
                ),
                if (hit.context case final context?) ...[
                  const SizedBox(width: EmberSpace.sm),
                  Flexible(
                    flex: 2,
                    child: Text(
                      context,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EmberType.body.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(
                    left: EmberSpace.sm,
                    right: EmberSpace.sm,
                  ),
                  child: Text(
                    kind,
                    maxLines: 1,
                    style: EmberType.label.copyWith(color: colors.inkTertiary),
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
