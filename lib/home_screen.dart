import 'dart:async';

import 'package:flutter/material.dart';

import 'native.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  AppState _state = AppState.idle;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = await NativeApi.getState();
    if (!mounted) return;
    setState(() {
      _state = next;
      _loading = false;
    });
  }

  Future<void> _setMode(BreakFreeMode mode) async {
    setState(() => _busy = true);
    await NativeApi.setMode(mode);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _setQuota(int minutes) async {
    setState(() => _busy = true);
    await NativeApi.setQuota(minutes);
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  String _fmtMs(int ms) {
    final min = ms ~/ 60000;
    final sec = (ms % 60000) ~/ 1000;
    return min > 0 ? '$min min' : '$sec sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _state;
    final isLevel1On = state.mode == BreakFreeMode.level1Timer;
    final needsService = !state.serviceEnabled;
    final needsOverlay = !state.overlayGranted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BreakFree'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(state: state),
            const SizedBox(height: 16),

            _LevelCard(
              level: 1,
              title: 'Daily Limit',
              description:
                  'Set how long you can use TikTok per day. Once reached, '
                  'TikTok is blocked until midnight.',
              icon: Icons.timelapse,
              busy: _busy,
              trailing: Switch(
                value: isLevel1On,
                onChanged: isLevel1On
                    ? null
                    : (_) => _setMode(BreakFreeMode.level1Timer),
              ),
              child: isLevel1On ? _buildLevel1Body(theme, state) : null,
            ),
            const SizedBox(height: 12),

            const _LevelCard(
              level: 2,
              title: 'Strict — 10 min',
              description:
                  'TikTok is fully blocked. Unblocking requires a 10 minute '
                  'wait. (Next build)',
              icon: Icons.lock_outline,
              busy: false,
              trailing: _ComingSoon(),
            ),
            const SizedBox(height: 12),

            const _LevelCard(
              level: 3,
              title: 'Strict — 30 min',
              description:
                  'TikTok is fully blocked. Unblocking requires a 30 minute '
                  'wait. (Next build)',
              icon: Icons.lock_outline,
              busy: false,
              trailing: _ComingSoon(),
            ),
            const SizedBox(height: 16),

            _PermissionCard(
              theme: theme,
              needsService: needsService,
              needsOverlay: needsOverlay,
            ),

            const SizedBox(height: 24),
            Text(
              'How it works',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'BreakFree uses an accessibility service to watch when TikTok is open '
              'and counts the time your daily limit. When the limit runs out, a '
              'full-screen block appears and you are taken out of TikTok until '
              'midnight.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevel1Body(ThemeData theme, AppState state) {
    final quota = state.quotaMin;
    final used = _fmtMs(state.usedTodayMs);
    final remaining = (state.quotaMs - state.usedTodayMs).clamp(0, state.quotaMs);
    final remainingStr = _fmtMs(remaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Daily quota', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '$quota min per day',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: state.usedFraction,
            minHeight: 10,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: state.isBlocked ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Used today: $used',
                style: theme.textTheme.bodyMedium),
            Text(
              state.isBlocked
                  ? 'Limit reached — blocked until midnight'
                  : 'Remaining: $remainingStr',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: state.isBlocked
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('How much per day?', style: theme.textTheme.titleSmall),
        Slider(
          value: quota.toDouble().clamp(15, 180),
          min: 15,
          max: 180,
          divisions: 11,
          label: '$quota min',
          onChanged: _busy
              ? null
              : (v) => setState(() {}),
          onChangeEnd: (v) => _setQuota(v.round()),
        ),
        Wrap(
          spacing: 8,
          children: [15, 30, 60, 90, 120, 180]
              .map((m) => ChoiceChip(
                    label: Text('$m'),
                    selected: quota == m,
                    onSelected: _busy ? null : (_) => _setQuota(m),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOn = state.mode != BreakFreeMode.off;
    final color = isOn ? theme.colorScheme.primary : theme.colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isOn ? Icons.shield_rounded : Icons.shield_outlined,
              color: color,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOn ? 'Protection active' : 'Protection is off',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOn
                        ? _levelLabel(state.mode)
                        : 'Turn on a level below to start protecting your time.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _levelLabel(BreakFreeMode mode) {
    switch (mode) {
      case BreakFreeMode.level1Timer:
        return 'Level 1 active — ${state.quotaMin} min of TikTok per day';
      default:
        return 'Level active';
    }
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.title,
    required this.description,
    required this.icon,
    required this.busy,
    required this.trailing,
    this.child,
  });

  final int level;
  final String title;
  final String description;
  final IconData icon;
  final bool busy;
  final Widget trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level $level — $title',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(description,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  trailing,
              ],
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: const Text('Next build'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.theme,
    required this.needsService,
    required this.needsOverlay,
  });

  final ThemeData theme;
  final bool needsService;
  final bool needsOverlay;

  @override
  Widget build(BuildContext context) {
    if (!needsService && !needsOverlay) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Setup', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (needsService) ...[
              _PermissionRow(
                icon: Icons.accessibility_new,
                title: 'Enable accessibility service',
                subtitle:
                    'Required to track TikTok usage and enforce the block.',
                buttonLabel: 'Open settings',
                onPressed: NativeApi.openAccessibilitySettings,
              ),
              const SizedBox(height: 8),
            ],
            if (needsOverlay) ...[
              _PermissionRow(
                icon: Icons.picture_in_picture_alt,
                title: 'Allow overlay (draw over apps)',
                subtitle: 'Shows the full-screen block when you hit your limit.',
                buttonLabel: 'Open settings',
                onPressed: NativeApi.openOverlaySettings,
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'After enabling, you may need to pull down to refresh this screen.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium),
              Text(subtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: onPressed,
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}