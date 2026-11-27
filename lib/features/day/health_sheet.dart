import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// نوع المتابعة من رمز العنصر (السكر أو الضغط أو غيرها).
HealthCheckKind? healthKindOf(PlanItem i) => i.category != 'health'
    ? null
    : HealthCheckKind.values.where((k) => k.icon == i.icon).firstOrNull;

/// نص القراءة المسجّلة: «120 ملغ/دل» أو «120/80 ملم زئبق».
String? readingText(HealthCheckKind k, ItemLog? log) {
  if (log?.value == null || k.unit == null) return null;
  final v = k == HealthCheckKind.pressure && log!.value2 != null
      ? '${log.value}/${log.value2}'
      : '${log!.value}';
  return nums('$v ${k.unit}');
}

/// «سجّل القراءة»: رقم واحد للسكر، ورقمان للضغط. تسجيل فقط بدون تقييم.
Future<void> logReading(
  BuildContext context,
  WidgetRef ref,
  PlanItem item,
  Day date,
) {
  final kind = healthKindOf(item) ?? HealthCheckKind.other;
  final a = TextEditingController();
  final b = TextEditingController();
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(item.title),
              Text(
                'سجّل الرقم كما يطلع في جهازك. التطبيق يحفظه لك فقط، وتقدر تعرضه على طبيبك.',
                style: T.meta.copyWith(color: ctx.c.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: a,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: kind == HealthCheckKind.pressure
                            ? 'الانقباضي (العالي)'
                            : 'القراءة',
                        suffixText: kind == HealthCheckKind.pressure
                            ? null
                            : kind.unit,
                      ),
                    ),
                  ),
                  if (kind == HealthCheckKind.pressure) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: b,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'الانبساطي (النازل)',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'احفظ',
                onPressed: () async {
                  final v = int.tryParse(a.text);
                  final v2 = int.tryParse(b.text);
                  await ref
                      .read(appDataProvider.notifier)
                      .markDone(date, item, value: v, value2: v2);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
