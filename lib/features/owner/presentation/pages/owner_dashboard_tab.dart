import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/owner_repository.dart';

class OwnerDashboardTab extends StatefulWidget {
  const OwnerDashboardTab({Key? key}) : super(key: key);

  @override
  State<OwnerDashboardTab> createState() => _OwnerDashboardTabState();
}

class _OwnerDashboardTabState extends State<OwnerDashboardTab> {
  final _repository = OwnerRepository();
  Map<String, dynamic>? _stats;
  String? _error;
  bool _isLoading = true;

  static final _money = NumberFormat.decimalPattern('fr_FR');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _repository.getDashboard();
      setState(() => _stats = stats);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // MySQL renvoie souvent les sommes en chaîne ("15000.00")
  num _num(dynamic v) => v is num ? v : num.tryParse('${v ?? 0}') ?? 0;

  String _fcfa(dynamic v) => '${_money.format(_num(v).round())} FCFA';

  String _monthLabel(String ym) {
    final date = DateTime.tryParse('$ym-01');
    return date == null ? ym : DateFormat('MMMM yyyy', 'fr_FR').format(date);
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'wave':
        return 'Wave';
      case 'orange_money':
        return 'Orange Money';
      case 'free_money':
        return 'Free Money';
      case 'card':
        return 'Carte';
      case 'cash':
        return 'Espèces';
      default:
        return method ?? 'Autre';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)),
            ElevatedButton(onPressed: _fetch, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final stats = _stats!;
    final monthly = (stats['monthly_revenue'] as List?) ?? [];
    final byField = (stats['revenue_by_field'] as List?) ?? [];
    final byMethod = (stats['revenue_by_method'] as List?) ?? [];
    final rentals = (stats['rentals'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.today, label: "Matchs aujourd'hui", value: '${_num(stats['today_reservations'])}')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(icon: Icons.event_available, label: 'Réservations', value: '${_num(stats['total_reservations'])}')),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(icon: Icons.payments, label: "Chiffre d'affaires total", value: _fcfa(stats['total_revenue'])),
          const SizedBox(height: 8),
          const Text(
            'Seules les réservations confirmées ou terminées sont comptées.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (byField.isNotEmpty) ...[
            _sectionTitle('Par terrain'),
            const Text('Touchez un terrain pour voir le détail de ses locations.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            ...byField.map((f) => _fieldRentals(f, rentals.where((r) => r['field_id'] == f['field_id']).toList())),
          ],
          if (monthly.isNotEmpty) ...[
            _sectionTitle('Par mois'),
            ...monthly.map((m) => _row(_monthLabel('${m['month']}'), _fcfa(m['revenue']))),
          ],
          if (byMethod.isNotEmpty) ...[
            _sectionTitle('Par moyen de paiement'),
            ...byMethod.map((m) => _row(_methodLabel(m['method']), _fcfa(m['total']))),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  String _rentalWhen(dynamic r) {
    final date = DateTime.tryParse('${r['date'] ?? ''}');
    String hhmm(dynamic t) => '${t ?? ''}'.length >= 5 ? '$t'.substring(0, 5) : '${t ?? ''}';
    final day = date == null ? '${r['date'] ?? ''}' : DateFormat('EEE d MMM', 'fr_FR').format(date);
    return '$day · ${hhmm(r['start_time'])} – ${hhmm(r['end_time'])}';
  }

  /// Un terrain : total encaissé, et au dépliage chaque location (date, heure, joueur, prix).
  Widget _fieldRentals(dynamic field, List<dynamic> rentals) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          shape: const Border(),
          title: Text(field['name'] ?? '-'),
          subtitle: Text('${rentals.length} location${rentals.length > 1 ? 's' : ''}'),
          trailing: Text(_fcfa(field['revenue']), style: const TextStyle(fontWeight: FontWeight.bold)),
          children: rentals
              .map((r) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.schedule, size: 20),
                    title: Text(_rentalWhen(r), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${r['player_name'] ?? '-'}  ·  ${r['player_phone'] ?? ''}'),
                    trailing: Text(_fcfa(r['total_price'])),
                  ))
              .toList(),
        ),
      );

  Widget _row(String label, String value) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(label),
          trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2E7D32)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
