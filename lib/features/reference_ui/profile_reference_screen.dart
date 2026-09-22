import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import 'reference_theme.dart';

class ProfileReferenceScreen extends ConsumerStatefulWidget {
  const ProfileReferenceScreen(
      {super.key, required this.demoMode, required this.onDemoChanged});
  final bool demoMode;
  final ValueChanged<bool> onDemoChanged;
  @override
  ConsumerState<ProfileReferenceScreen> createState() =>
      _ProfileReferenceScreenState();
}

class _ProfileReferenceScreenState
    extends ConsumerState<ProfileReferenceScreen> {
  bool busy = false;
  String? message;
  Future<void> connect({bool sync = false}) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final service = ref.read(healthConnectServiceProvider);
      if (!await service.checkAvailability()) {
        if (mounted) {
          setState(() => message =
              'Health Connect is unavailable on this device. Set it up on a supported Android device first.');
        }
        return;
      }
      if (sync) {
        final result = await ref.read(healthSyncProvider.notifier).sync();
        if (mounted) {
          setState(
              () => message = result.message ?? 'Sync ${result.phase.name}.');
        }
      } else {
        final granted = await service.requestPermissions();
        ref.invalidate(healthPermissionsProvider);
        ref.invalidate(dailySummaryProvider);
        if (mounted) {
          setState(() => message = granted
              ? 'Health Connect access granted. You can now sync your readings.'
              : 'Access was not granted. You can retry when ready.');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Unable to access the health source. Check Health Connect availability and permissions, then retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: referenceBackground,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 112),
          children: [
            Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('FITX VITALITY', style: referenceCaption),
                          const SizedBox(height: 4),
                          const Text('Profile',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 24),
                          const ReferenceCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Icon(Icons.person_outline,
                                    size: 36, color: referenceBlue),
                                SizedBox(height: 12),
                                Text('Your health, clearly',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: 8),
                                Text(
                                    'FitX brings your available recovery, activity and sleep signals together.')
                              ])),
                          const SizedBox(height: 16),
                          ReferenceCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                SwitchListTile.adaptive(
                                    key: const ValueKey('demo-toggle'),
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Demo mode'),
                                    subtitle: Text(widget.demoMode
                                        ? 'Sample readings · not your health data'
                                        : 'Your data · missing readings stay empty'),
                                    value: widget.demoMode,
                                    onChanged: widget.onDemoChanged),
                                const Text(
                                    'Demo mode uses the supplied design examples. It never writes sample readings to your health history.',
                                    style: TextStyle(
                                        fontSize: 13, color: referenceMuted))
                              ])),
                          const SizedBox(height: 16),
                          ReferenceCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('HEALTH SOURCES',
                                    style: referenceCaption),
                                const SizedBox(height: 12),
                                const Text('Health Connect',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Use the existing Android health connection to request access or refresh saved readings. Source apps and permissions control what is available.'),
                                const SizedBox(height: 16),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  FilledButton(
                                      onPressed: busy || widget.demoMode
                                          ? null
                                          : () => connect(),
                                      child: const Text('Connect source')),
                                  OutlinedButton(
                                      onPressed: busy || widget.demoMode
                                          ? null
                                          : () => connect(sync: true),
                                      child: const Text('Sync readings'))
                                ]),
                                if (widget.demoMode)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 12),
                                      child: Text(
                                          'Turn off demo mode to connect your data.',
                                          style: TextStyle(
                                              color: referenceMuted))),
                                if (busy) const LinearProgressIndicator(),
                                if (message != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Semantics(
                                          liveRegion: true,
                                          child: Text(message!)))
                              ])),
                          const SizedBox(height: 16),
                          const ReferenceCard(
                              child: Text(
                                  'Recovery estimates require enough personal baseline data. Skin temperature and prescribed training windows are not available from the current source integration.')),
                        ])))
          ]));
}
