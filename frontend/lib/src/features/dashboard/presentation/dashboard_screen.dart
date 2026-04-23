import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:glassmorphism/glassmorphism.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ARQUÉTIPOS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dinâmicas Psíquicas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
            ),
            const SizedBox(height: 24),
            _buildRadarChart(),
            const SizedBox(height: 32),
            const Text(
              'Estágios da Jornada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildJourneyStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarChart() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 300,
      borderRadius: 24,
      blur: 15,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
      borderGradient: LinearGradient(colors: [const Color(0xFFD4AF37).withOpacity(0.3), Colors.transparent]),
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              fillColor: const Color(0xFFD4AF37).withOpacity(0.4),
              borderColor: const Color(0xFFD4AF37),
              entryRadius: 3,
              dataEntries: [
                const RadarEntry(value: 8), // Sombra
                const RadarEntry(value: 5), // Persona
                const RadarEntry(value: 4), // Herói
                const RadarEntry(value: 7), // Anima
                const RadarEntry(value: 3), // Velho Sábio
              ],
            ),
          ],
          radarBackgroundColor: Colors.transparent,
          getTitle: (index, angle) {
            switch (index) {
              case 0: return const RadarChartTitle(text: 'Sombra');
              case 1: return const RadarChartTitle(text: 'Persona');
              case 2: return const RadarChartTitle(text: 'Herói');
              case 3: return const RadarChartTitle(text: 'Anima');
              case 4: return const RadarChartTitle(text: 'Sábio');
              default: return const RadarChartTitle(text: '');
            }
          },
        ),
      ),
    );
  }

  Widget _buildJourneyStats() {
    return Column(
      children: [
        _buildStatRow('Chamado à Aventura', 0.8),
        _buildStatRow('Travessia do Limiar', 0.4),
        _buildStatRow('Ventre da Baleia', 0.2),
      ],
    );
  }

  Widget _buildStatRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
          ),
        ],
      ),
    );
  }
}
