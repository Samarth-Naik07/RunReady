import 'run_score_models.dart';

/// How the alternative running windows are ordered.
enum RunWindowSort {
  highestScore('Highest Run Score'),
  earliestTime('Earliest Time');

  const RunWindowSort(this.label);

  /// Text shown on the sort control.
  final String label;
}

/// A window with its place in the Run Score ranking (the best window is #1).
///
/// The rank stays with the window when the list is re-sorted, so "#3" always
/// means the third-best score.
typedef RankedRunWindow = ({int rank, RunWindow window});

/// Returns [windows] in the order chosen by [sort], without changing them.
///
/// - [RunWindowSort.highestScore]: highest score first; ties go to the earlier
///   window.
/// - [RunWindowSort.earliestTime]: earliest start first.
List<RankedRunWindow> sortRunWindows(
  List<RankedRunWindow> windows,
  RunWindowSort sort,
) {
  final sorted = [...windows];

  switch (sort) {
    case RunWindowSort.highestScore:
      sorted.sort((a, b) {
        final byScore = b.window.score.compareTo(a.window.score);
        return byScore != 0
            ? byScore
            : a.window.start.compareTo(b.window.start);
      });
    case RunWindowSort.earliestTime:
      sorted.sort((a, b) => a.window.start.compareTo(b.window.start));
  }

  return List.unmodifiable(sorted);
}
