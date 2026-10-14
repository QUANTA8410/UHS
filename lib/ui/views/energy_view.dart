import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/home_state.dart';

class EnergyView extends StatelessWidget {
  const EnergyView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HomeState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartThings Energy Hub', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live Usage Gauge Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('Real-Time Household Power Draw', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 10),
                  Text(
                    '${state.totalPowerWatts.toStringAsFixed(0)} W',
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_down, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        state.aiEnergyModeEnabled
                            ? 'AI Energy Mode active (15% power reduced)'
                            : 'Normal operating mode',
                        style: TextStyle(
                          color: state.aiEnergyModeEnabled ? Colors.green : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LinearProgressIndicator(
                    value: (state.totalPowerWatts / 3000.0).clamp(0.0, 1.0),
                    backgroundColor: Colors.deepPurple.shade50,
                    color: Colors.deepPurple,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('0 kW', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Safe Threshold: 3.0 kW', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Peak Hour Advisory Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: state.energyPrediction.isCurrentlyPeakHour
                  ? Colors.amber.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: state.energyPrediction.isCurrentlyPeakHour
                    ? Colors.amber.shade300
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  state.energyPrediction.isCurrentlyPeakHour
                      ? Icons.electric_bolt_rounded
                      : Icons.eco_rounded,
                  color: state.energyPrediction.isCurrentlyPeakHour
                      ? Colors.amber.shade800
                      : Colors.green.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.energyOptimizerService.getPeakHourAdvice(DateTime.now()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: state.energyPrediction.isCurrentlyPeakHour
                          ? Colors.amber.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tariff & Projections Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tariff & Cost Projections',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: state.energyPrediction.isCurrentlyPeakHour
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.energyPrediction.isCurrentlyPeakHour ? 'PEAK RATE' : 'OFF-PEAK RATE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: state.energyPrediction.isCurrentlyPeakHour
                                ? Colors.red.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Current Cost',
                          value: '\$${state.energyPrediction.hourlyCostNow.toStringAsFixed(3)}/hr',
                          icon: Icons.speed_rounded,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Estimated Bill',
                          value: '\$${state.energyPrediction.monthlyCostEstimate.toStringAsFixed(2)}/mo',
                          icon: Icons.receipt_long_rounded,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'AI Mode Savings',
                          value: '-\$${state.energyPrediction.monthlySavingsWithAiMode.toStringAsFixed(2)}/mo',
                          icon: Icons.savings_outlined,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Carbon Avoided',
                          value: '${state.energyPrediction.carbonAvoidedKgPerMonth.toStringAsFixed(1)} kg CO₂',
                          icon: Icons.forest_outlined,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Samsung SmartThings AI Energy Mode Switcher
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.indigo.shade600],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.amber, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'AI Energy Mode (SmartThings)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Optimizes compressor frequencies and dimming to hit carbon targets',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.aiEnergyModeEnabled,
                  activeThumbColor: Colors.amber,
                  onChanged: (val) => state.toggleAiEnergyMode(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Device Energy Breakdown
          const Text('Live Breakdown by Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ...state.allDevices.map((d) {
            final double currentWatts = d.isPowered ? d.powerUsageWatts : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(d.icon, color: Colors.deepPurple),
                title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${d.room} • ${d.isPowered ? "Running" : "Standby"}'),
                trailing: Text(
                  '${currentWatts.toStringAsFixed(0)} W',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: d.isPowered ? Colors.deepPurple : Colors.grey,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}
