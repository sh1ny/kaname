/// The benchmark panel: progress with Cancel while a run is going, then the
/// figures against their budgets with "Copy JSON".
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../logic/bench_metrics.dart';
import '../logic/bench_script.dart';
import '../logic/benchmark_notifier.dart';
import '../logic/benchmark_result.dart';

/// The name of [step] on screen.
String benchStepLabel(BenchStep step) => switch (step) {
  BenchStep.calibrate => 'Calibrating the refresh period',
  BenchStep.handSpeed => 'Scrolling at hand speed',
  BenchStep.stressDown => 'Stress scroll down',
  BenchStep.stressUp => 'Stress scroll up',
  BenchStep.horizontalOut => 'Scrolling to the last column',
  BenchStep.horizontalBack => 'Scrolling back to the first column',
  BenchStep.filter => 'Filter',
  BenchStep.category => 'Category filter',
  BenchStep.sortText => 'Sort by text',
  BenchStep.sortInteger => 'Sort by integer',
  BenchStep.sortFloat => 'Sort by decimal',
  BenchStep.groupFirst => 'Group by one column',
  BenchStep.groupSecond => 'Group by another column',
  BenchStep.collapseAll => 'Collapse all groups',
  BenchStep.expandAll => 'Expand all groups',
  BenchStep.clear => 'Clear the query',
  BenchStep.sortTextFull => 'Sort all rows by text',
  BenchStep.sortIntegerFull => 'Sort all rows by integer',
  BenchStep.sortFloatFull => 'Sort all rows by decimal',
  BenchStep.groupFirstFull => 'Group all rows by one column',
  BenchStep.groupSecondFull => 'Group all rows by another column',
  BenchStep.resize => 'Resize a column',
  BenchStep.settle => 'Collecting the last frame timings',
};

/// The words for why a run stopped.
String _abortText(String reason) => switch (reason.split(':')) {
  ['cancelled'] => 'cancelled',
  ['grid-not-ready'] => 'the grid had no data',
  ['calibration-failed'] => 'no frames were drawn while calibrating',
  ['timeout', final step] => 'the step "$step" took too long',
  _ => reason,
};

/// Shows the state of the benchmark above the grid.
///
/// Nothing while idle. While running, the step and a Cancel button. After a
/// run, the figures or the reason it stopped; "Close" hides them until the
/// next run.
class BenchPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const BenchPanel({super.key});

  @override
  ConsumerState<BenchPanel> createState() => _BenchPanelState();
}

class _BenchPanelState extends ConsumerState<BenchPanel> {
  BenchmarkState? _closed;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(benchmarkProvider);
    if (identical(state, _closed)) return const SizedBox.shrink();
    void close() => setState(() => _closed = state);
    return switch (state) {
      Idle() => const SizedBox.shrink(),
      Running(:final step) => _Strip(
        message:
            '${benchStepLabel(step)} (${step.index + 1} of '
            '${BenchStep.values.length})',
        title: 'Benchmark running',
        actionLabel: 'Cancel',
        onAction: ref.read(benchmarkProvider.notifier).cancel,
      ),
      Aborted(:final reason) => _Strip(
        title: 'Benchmark stopped',
        message: 'Stopped because ${_abortText(reason)}.',
        actionLabel: 'Close',
        onAction: close,
        error: true,
      ),
      Done(:final result) => _ResultView(result: result, onClose: close),
    };
  }
}

/// One line: a title, a message and one action.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.error = false,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EmberSpace.md,
        vertical: EmberSpace.sm,
      ),
      decoration: BoxDecoration(
        color: error ? colors.errBg : colors.panel,
        border: Border(
          bottom: BorderSide(color: error ? colors.errLine : colors.hairline),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: EmberType.uiHeading.copyWith(
              color: error ? colors.errInk : colors.ink,
            ),
          ),
          const SizedBox(width: EmberSpace.md),
          Expanded(
            child: Text(
              message,
              style: EmberType.body.copyWith(color: colors.inkSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: EmberSpace.md),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// The figures of a finished run against their budgets.
class _ResultView extends StatefulWidget {
  const _ResultView({required this.result, required this.onClose});

  final BenchmarkResult result;
  final VoidCallback onClose;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  bool _copied = false;

  Future<void> _copy() async {
    final json = const JsonEncoder.withIndent('  ')
        .convert(widget.result.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final result = widget.result;
    final verdict = result.verdict;
    final judged = result.segments.firstWhere((s) => s.judged);
    final environment = result.environment;
    final rows = <_Figure>[
      _Figure(
        'Missed frames, hand speed',
        '${(judged.stats.missedRatio * 100).toStringAsFixed(1)} %',
        '≤ ${(maxMissedRatio * 100).toStringAsFixed(0)} %',
        verdict.missedOk,
      ),
      _Figure(
        'Time between frames, p99',
        _ms(judged.stats.p99Ms),
        '≤ $maxP99Periods refresh periods '
            '(< ${_ms((maxP99Periods + 0.5) * judged.stats.periodMs)})',
        verdict.p99Ok,
      ),
      _Figure(
        'Build plus raster, p90',
        judged.workP90Ms == null ? 'not reported' : _ms(judged.workP90Ms!),
        '≤ ${_ms(maxWorkP90Ms)}',
        verdict.workOk,
      ),
      for (final op in result.operations)
        _Figure(
          benchStepLabel(op.step),
          '${_ms(op.untilOnScreenMs)} on screen'
              '${op.engineMs == null ? '' : ', engine ${_ms(op.engineMs!)}'}',
          '≤ ${_ms(maxOperationMs)}',
          op.untilOnScreenMs <= maxOperationMs,
        ),
      for (final segment in result.segments.where((s) => !s.judged))
        _Figure(
          benchStepLabel(segment.step),
          '${(segment.stats.missedRatio * 100).toStringAsFixed(1)} % missed, '
              'p99 ${_ms(segment.stats.p99Ms)}',
          'headroom',
          null,
        ),
    ];
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      padding: const EdgeInsets.all(EmberSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Benchmark result',
                style: EmberType.uiHeading.copyWith(color: colors.ink),
              ),
              const SizedBox(width: EmberSpace.md),
              _Mark(
                verdict.passed,
                passLabel: 'S4 met',
                failLabel: 'S4 not met',
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _copy,
                child: Text(_copied ? 'Copied' : 'Copy JSON'),
              ),
              const SizedBox(width: EmberSpace.sm),
              TextButton(onPressed: widget.onClose, child: const Text('Close')),
            ],
          ),
          const SizedBox(height: EmberSpace.xs),
          Text(
            '${environment.renderer} · threads ${environment.threadMode}'
            ' · refresh ${_ms(result.refreshPeriodMs)}'
            ' · ${result.config.name} script'
            '${result.droppedSamples == 0 ? '' : ' · ${result.droppedSamples} samples dropped'}',
            style: EmberType.label.copyWith(color: colors.inkTertiary),
          ),
          const SizedBox(height: EmberSpace.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(4),
                  2: FlexColumnWidth(2),
                  3: FixedColumnWidth(136),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [for (final row in rows) row.build(colors)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _ms(double value) => '${value.toStringAsFixed(1)} ms';
}

/// One row of the figures table.
class _Figure {
  const _Figure(this.name, this.value, this.budget, this.ok);

  final String name;
  final String value;
  final String budget;

  /// Whether the figure is within its budget; `null` when not judged.
  final bool? ok;

  TableRow build(EmberColors colors) {
    final text = EmberType.body.copyWith(
      color: colors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget cell(String data, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(data, style: style ?? text),
    );
    return TableRow(
      children: [
        cell(name),
        cell(value),
        cell(budget, style: text.copyWith(color: colors.inkSecondary)),
        ok == null
            ? cell(
                'not judged',
                style: text.copyWith(color: colors.inkTertiary),
              )
            : _Mark(ok!),
      ],
    );
  }
}

/// A pass or fail mark that does not rely on colour alone: an icon and words.
class _Mark extends StatelessWidget {
  const _Mark(
    this.ok, {
    this.passLabel = 'Pass',
    this.failLabel = 'Over budget',
  });

  final bool ok;
  final String passLabel;
  final String failLabel;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    final color = ok ? colors.ok : colors.errInk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check : Icons.close,
          size: EmberSize.icon,
          color: color,
        ),
        const SizedBox(width: EmberSpace.xs),
        Text(
          ok ? passLabel : failLabel,
          style: EmberType.label.copyWith(color: color),
        ),
      ],
    );
  }
}
