import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/appliance_recipes.dart';
import '../../../models/device_model.dart';
import '../../../providers/home_state.dart';

class ApplianceCycleStoreSheet extends StatelessWidget {
  final WasherDevice washer;

  const ApplianceCycleStoreSheet({super.key, required this.washer});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.cloud_download_rounded, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LG ThinQ UP™ Cycle Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Download specialized wash algorithms over-the-air', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: WashCycleRecipe.downloadableCatalog.map((recipe) {
                final isInstalled = state.availableWashCycles.any((c) => c.id == recipe.id);
                final isCurrent = washer.selectedCycle == recipe.name;

                return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${recipe.durationMinutes} min • ${recipe.defaultTempC}°C'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(recipe.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isCurrent)
                          const Chip(
                            backgroundColor: Colors.greenAccent,
                            label: Text('Active on Washer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          )
                        else if (isInstalled)
                          FilledButton.tonal(
                            onPressed: () {
                              state.updateWasher(washer.id, cycle: recipe.name);
                              Navigator.pop(context);
                            },
                            child: const Text('Apply Cycle'),
                          )
                        else
                          FilledButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Download to Washer'),
                            onPressed: () {
                              state.downloadCycle(recipe);
                              state.updateWasher(washer.id, cycle: recipe.name);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Downloaded "${recipe.name}" to LG WashTower!')),
                              );
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
