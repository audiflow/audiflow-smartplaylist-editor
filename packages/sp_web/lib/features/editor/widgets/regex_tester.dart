import 'dart:async';

import 'package:flutter/material.dart';

/// Hardcoded sample episode titles for regex testing.
const _sampleTitles = [
  'Season 1 Episode 1: Introduction',
  'Season 1 Episode 2: Getting Started',
  'Season 2 Episode 1: Advanced Topics',
  'Bonus: Interview with Expert',
  'Special Episode: Behind the Scenes',
  '[番外編] Extra Content',
  'S03E01 - New Beginnings',
  'Trailer: Coming Soon',
];

/// Inline regex tester that shows match highlighting against sample titles.
///
/// Displays a compact expandable section with a list of sample episode titles.
/// Matching text is highlighted based on [highlightColor].
class RegexTester extends StatefulWidget {
  const RegexTester({
    super.key,
    required this.pattern,
    this.sampleTexts = _sampleTitles,
    this.label,
    this.highlightColor,
  });

  /// Current regex pattern to test.
  final String pattern;

  /// Episode titles to test against.
  final List<String> sampleTexts;

  /// Label displayed in the expansion header (e.g. "Title Filter").
  final String? label;

  /// Color used to highlight matches. Defaults to green for include
  /// filters; pass red for exclude filters.
  final Color? highlightColor;

  @override
  State<RegexTester> createState() => _RegexTesterState();
}

class _RegexTesterState extends State<RegexTester> {
  Timer? _debounceTimer;
  String _debouncedPattern = '';
  RegExp? _compiledRegex;
  String? _regexError;

  @override
  void initState() {
    super.initState();
    _debouncedPattern = widget.pattern;
    _compilePattern(_debouncedPattern);
  }

  @override
  void didUpdateWidget(RegexTester oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern != widget.pattern) {
      _schedulePatternUpdate(widget.pattern);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _schedulePatternUpdate(String pattern) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _debouncedPattern = pattern;
        _compilePattern(pattern);
      });
    });
  }

  void _compilePattern(String pattern) {
    if (pattern.isEmpty) {
      _compiledRegex = null;
      _regexError = null;
      return;
    }
    try {
      _compiledRegex = RegExp(pattern, caseSensitive: false);
      _regexError = null;
    } on FormatException catch (e) {
      _compiledRegex = null;
      _regexError = e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pattern.isEmpty && _debouncedPattern.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final matchColor =
        widget.highlightColor ?? Colors.green.withValues(alpha: 0.3);

    final matchCount = _countMatches();
    final totalCount = widget.sampleTexts.length;
    final headerLabel = widget.label ?? 'Regex Tester';

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        dense: true,
        title: Row(
          children: [
            Text(
              headerLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(width: 8),
            if (_regexError != null)
              Text(
                'Invalid regex',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              )
            else if (_debouncedPattern.isNotEmpty)
              Text(
                '$matchCount of $totalCount match',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
          ],
        ),
        children: [
          if (_regexError != null)
            _buildErrorMessage(theme, colorScheme)
          else
            ...widget.sampleTexts.map(
              (title) => _buildSampleRow(title, matchColor, theme),
            ),
        ],
      ),
    );
  }

  int _countMatches() {
    final regex = _compiledRegex;
    if (regex == null) return 0;
    return widget.sampleTexts.where((title) => regex.hasMatch(title)).length;
  }

  Widget _buildErrorMessage(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        _regexError ?? '',
        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
      ),
    );
  }

  Widget _buildSampleRow(String title, Color matchColor, ThemeData theme) {
    final regex = _compiledRegex;
    final isMatch = regex != null && regex.hasMatch(title);
    final textStyle =
        theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 14,
            color: isMatch
                ? matchColor.withValues(alpha: 1)
                : theme.colorScheme.outlineVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: isMatch
                ? _buildHighlightedText(title, regex, matchColor, textStyle)
                : Text(
                    title,
                    style: textStyle.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    RegExp regex,
    Color matchColor,
    TextStyle baseStyle,
  ) {
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Skip zero-length matches to avoid infinite highlighting.
      if (match.start == match.end) continue;

      if (lastEnd < match.start) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: matchColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    // Fallback when no non-zero-length matches were found.
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return RichText(
      text: TextSpan(
        style: baseStyle.copyWith(color: baseStyle.color ?? Colors.black87),
        children: spans,
      ),
    );
  }
}
