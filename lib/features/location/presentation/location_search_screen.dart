import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout.dart';
import '../data/location_models.dart';
import '../data/location_repository.dart';
import '../providers/location_provider.dart';

/// Lets the user search for a place and switch the weather to it.
class LocationSearchScreen extends ConsumerStatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  ConsumerState<LocationSearchScreen> createState() =>
      _LocationSearchScreenState();
}

class _LocationSearchScreenState extends ConsumerState<LocationSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(GeoLocation location) {
    ref.read(selectedLocationProvider.notifier).select(location);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(locationSearchProvider);
    final selected = ref.watch(selectedLocationProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Location'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false, // the AppBar already handles the top inset
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = contentSidePadding(constraints.maxWidth);

            return Padding(
              padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 0),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: ref
                        .read(locationSearchProvider.notifier)
                        .onQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Search city, e.g. Mumbai',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colorScheme.primary,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: switch (results) {
                      null => _Message(
                        icon: Icons.travel_explore_rounded,
                        text:
                            'Type at least ${LocationRepository.minQueryLength} '
                            'letters to search.',
                      ),
                      AsyncData(:final value) when value.isEmpty => _Message(
                        icon: Icons.location_off_outlined,
                        text:
                            'No places found for "${_controller.text.trim()}".',
                      ),
                      AsyncData(:final value) => _ResultsList(
                        locations: value,
                        selectedId: selected.id,
                        onSelect: _select,
                      ),
                      AsyncError() => _Message(
                        icon: Icons.cloud_off_rounded,
                        text: "Couldn't search right now.",
                        action: FilledButton.tonal(
                          onPressed: ref
                              .read(locationSearchProvider.notifier)
                              .retry,
                          child: const Text('Retry'),
                        ),
                      ),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// White rounded card with one row per place.
class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.locations,
    required this.selectedId,
    required this.onSelect,
  });

  final List<GeoLocation> locations;

  /// The currently selected place, marked with a check.
  final int selectedId;
  final void Function(GeoLocation location) onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, location) in locations.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 72),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    location.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: location.areaDescription.isEmpty
                      ? null
                      : Text(location.areaDescription),
                  trailing: location.id == selectedId
                      ? Icon(Icons.check_rounded, color: colorScheme.primary)
                      : null,
                  onTap: () => onSelect(location),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A centered icon and message, with an optional button.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: const Alignment(0, -0.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}
