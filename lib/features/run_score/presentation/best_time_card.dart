import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';

import '../domain/run_score_models.dart';
import '../domain/run_window_summary.dart';
import 'run_window_format.dart';

/// White rounded card showing the recommended 2-hour running window.
///
/// Only displays [window]; all scoring happens in the Run Score providers.
class BestTimeCard extends StatelessWidget {
  const BestTimeCard({
    super.key,
    required this.window,
    required this.now,
    required this.onRetry,
  });

  /// The best window from `bestRunWindowProvider`.
  final AsyncValue<RunWindow?> window;

  /// Used to label the window as "Today" or "Tomorrow".
  final DateTime now;

  /// Called when the user taps Retry after an error.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_run_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Best Time to Run',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          window.when(
            // Show the spinner while Retry is running, too.
            skipLoadingOnRefresh: false,
            loading: () => const _LoadingState(),
            error: (error, stackTrace) => _ErrorState(
              message: AppError.from(error).userMessage,
              onRetry: onRetry,
            ),
            data: (window) => window == null
                ? const _NoWindowState()
                : _Recommendation(window: window, now: now),
          ),
        ],
      ),
    );
  }
}

/// Time range, score, score bar, and explanation.
class _Recommendation extends StatelessWidget {
  const _Recommendation({required this.window, required this.now});

  final RunWindow window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final score = window.score.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dayLabel(window.start, now),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),

        // Wrap puts the score badge next to the time, or below it when the
        // screen is too narrow for both on one line.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              formatWindowRange(window),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text.rich(
                TextSpan(
                  text: '$score',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: ' / 100',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: window.score / 100,
            minHeight: 6,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          describeRunWindow(window),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 12),
        // Flexible lets the text wrap instead of overflowing with large fonts.
        Flexible(
          child: Text(
            'Finding the best time…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  /// A friendly message for the error, never raw exception text.
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 20, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

class _NoWindowState extends StatelessWidget {
  const _NoWindowState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No suitable 2-hour window found',
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
