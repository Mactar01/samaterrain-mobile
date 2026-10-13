import 'package:flutter/material.dart';
import '../../data/owner_repository.dart';

class OwnerReservationsTab extends StatefulWidget {
  const OwnerReservationsTab({Key? key}) : super(key: key);

  @override
  State<OwnerReservationsTab> createState() => _OwnerReservationsTabState();
}

class _OwnerReservationsTabState extends State<OwnerReservationsTab> {
  final _repository = OwnerRepository();
  List<dynamic> _reservations = [];
  String? _error;
  bool _isLoading = true;

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
      final reservations = await _repository.getReservations();
      setState(() => _reservations = reservations);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      _showSnack(successMessage, Colors.green);
      await _fetch();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _confirmCancel(dynamic reservation) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler cette réservation ?'),
        content: const Text('Le créneau redeviendra disponible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _repository.cancelReservation(reservation['id']), 'Réservation annulée.');
    }
  }

  (Color, String) _status(String? status) {
    switch (status) {
      case 'pending':
        return (Colors.orange, 'En attente');
      case 'confirmed':
        return (Colors.green, 'Confirmée');
      case 'completed':
        return (Colors.blue, 'Terminée');
      case 'cancelled':
        return (Colors.red, 'Annulée');
      default:
        return (Colors.grey, status ?? 'Inconnu');
    }
  }

  String _time(dynamic t) => '${t ?? ''}'.length >= 5 ? '$t'.substring(0, 5) : '${t ?? ''}';

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

    return RefreshIndicator(
      onRefresh: _fetch,
      child: _reservations.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('Aucune réservation pour le moment.')),
            ])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _reservations.length,
              itemBuilder: (context, index) {
                final r = _reservations[index];
                final user = r['user'] ?? {};
                final field = r['field'] ?? {};
                final slot = r['time_slot'] ?? {};
                final (color, label) = _status(r['status']);
                final canAct = r['status'] == 'pending' || r['status'] == 'confirmed';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(field['name'] ?? 'Terrain',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('📅 ${slot['date'] ?? '-'}   🕒 ${_time(slot['start_time'])} - ${_time(slot['end_time'])}'),
                        const SizedBox(height: 4),
                        // Réservation manuelle : le client est noté sur la réservation (guest_*)
                        Text('👤 ${r['guest_name'] ?? user['name'] ?? '-'}   📞 ${r['guest_phone'] ?? user['phone'] ?? '-'}'),
                        const SizedBox(height: 4),
                        Text('💰 ${r['total_price'] ?? '-'} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (canAct)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () => _confirmCancel(r),
                                child: const Text('Annuler'),
                              ),
                              if (r['status'] == 'pending')
                                TextButton(
                                  onPressed: () => _run(() => _repository.confirmReservation(r['id']), 'Réservation confirmée.'),
                                  child: const Text('Confirmer'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
