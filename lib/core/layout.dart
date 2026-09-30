import 'dart:math';

/// The widest the content column gets on tablets, desktop, and landscape.
const maxContentWidth = 480.0;

/// Side padding that keeps at least 20px on each side and centers the content
/// in a phone-width column when the screen is wider than [maxContentWidth].
double contentSidePadding(double screenWidth) {
  return max(20.0, (screenWidth - maxContentWidth) / 2);
}
