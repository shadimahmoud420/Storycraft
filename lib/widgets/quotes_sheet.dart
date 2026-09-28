import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../data/quotes.dart';

/// Lets the user pick a ready-made phrase. Returns the chosen text.
Future<String?> showQuotesSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _QuotesSheet(),
  );
}

class _QuotesSheet extends StatefulWidget {
  const _QuotesSheet();

  @override
  State<_QuotesSheet> createState() => _QuotesSheetState();
}

class _QuotesSheetState extends State<_QuotesSheet> {
  QuoteCategory _category = QuoteCategory.adhkar;

  String _label(S s, QuoteCategory c) => switch (c) {
        QuoteCategory.adhkar => s.adhkar,
        QuoteCategory.morning => s.morning,
        QuoteCategory.wisdom => s.wisdom,
        QuoteCategory.motivation => s.motivation,
        QuoteCategory.english => s.english,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = quotes[_category]!;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final c in QuoteCategory.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(_label(s, c)),
                      selected: c == _category,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) => Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, items[i]),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      items[i],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
