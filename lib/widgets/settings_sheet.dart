import 'package:flutter/material.dart';

import '../core/date_text.dart';
import '../core/strings.dart';
import '../services/app_settings.dart';
import '../services/reminder_service.dart';

/// App settings: watermark, Hijri adjustment and the daily reminder.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  Future<void> _toggleReminder(BuildContext context, bool on) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final settings = AppSettings.instance;
    if (on && !await ReminderService.instance.requestPermission()) {
      messenger.showSnackBar(SnackBar(content: Text(s.reminderDenied)));
      return;
    }
    await settings.update(settings.value.copyWith(reminderOn: on));
    await ReminderService.instance.sync(title: s.reminderTitle);
  }

  Future<void> _pickTime(BuildContext context) async {
    final s = S.of(context);
    final settings = AppSettings.instance;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.value.reminderHour,
        minute: settings.value.reminderMinute,
      ),
    );
    if (picked == null) return;
    await settings.update(settings.value
        .copyWith(reminderHour: picked.hour, reminderMinute: picked.minute));
    await ReminderService.instance.sync(title: s.reminderTitle);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: ValueListenableBuilder<AppSettingsData>(
        valueListenable: AppSettings.instance,
        builder: (context, v, _) {
          final today = DateTime.now();
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(s.settings, style: theme.textTheme.titleLarge),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.verified_rounded),
                  title: Text(s.watermarkSetting),
                  subtitle: Text(s.watermarkHint),
                  value: v.showWatermark,
                  onChanged: (on) => AppSettings.instance
                      .update(v.copyWith(showWatermark: on)),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_rounded),
                  title: Text(s.reminder),
                  subtitle: Text(s.reminderHint),
                  value: v.reminderOn,
                  onChanged: (on) => _toggleReminder(context, on),
                ),
                if (v.reminderOn)
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(s.reminderTime),
                    trailing: Text(
                      TimeOfDay(hour: v.reminderHour, minute: v.reminderMinute)
                          .format(context),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: () => _pickTime(context),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.nightlight_round),
                  title: Text(s.hijriAdjust),
                  subtitle: Text('${s.hijriAdjustHint}\n${DateText.hijri(today)}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: v.hijriOffset <= -2
                            ? null
                            : () => AppSettings.instance.update(
                                v.copyWith(hijriOffset: v.hijriOffset - 1)),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          v.hijriOffset > 0 ? '+${v.hijriOffset}' : '${v.hijriOffset}',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: v.hijriOffset >= 2
                            ? null
                            : () => AppSettings.instance.update(
                                v.copyWith(hijriOffset: v.hijriOffset + 1)),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
