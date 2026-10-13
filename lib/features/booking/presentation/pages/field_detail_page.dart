import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';
import '../../../fields/data/field_options.dart';
import '../../../fields/data/field_repository.dart';
import '../bloc/booking_cubit.dart';

/// Fiche d'un terrain : photos, infos, équipements, contact du gérant, puis créneaux réservables.
class FieldDetailPage extends StatefulWidget {
  final int fieldId;
  const FieldDetailPage({Key? key, required this.fieldId}) : super(key: key);

  @override
  State<FieldDetailPage> createState() => _FieldDetailPageState();
}

class _FieldDetailPageState extends State<FieldDetailPage> {
  static const _green = Color(0xFF2E7D32);
  static final _money = NumberFormat.decimalPattern('fr_FR');

  final _photoController = PageController();
  int _photoIndex = 0;

  Map<String, dynamic>? _field;
  String? _fieldError;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadField();
    _fetchSlots();
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _loadField() async {
    try {
      final field = await FieldRepository().getField(widget.fieldId);
      if (mounted) setState(() => _field = field);
    } catch (_) {
      if (mounted) setState(() => _fieldError = 'Impossible de charger le terrain.');
    }
  }

  void _fetchSlots() {
    context.read<BookingCubit>().fetchSlots(widget.fieldId, DateFormat('yyyy-MM-dd').format(_selectedDate));
  }

  // ─── Helpers ───

  String _fcfa(num v) => '${_money.format(v.round())} FCFA';

  num? _toNum(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');

  num? _slotPrice(dynamic slot) => _toNum(slot['promo_price']) ?? _toNum(slot['price']) ?? _toNum(_field?['price_per_hour']);

  String _hhmm(dynamic t) => '${t ?? ''}'.length >= 5 ? '$t'.substring(0, 5) : '${t ?? ''}';

  /// Créneau d'aujourd'hui déjà commencé : on ne le propose plus.
  bool _isPast(dynamic slot) {
    final now = DateTime.now();
    if (_selectedDate.isAfter(DateTime(now.year, now.month, now.day))) return false;
    final parts = _hhmm(slot['start_time']).split(':');
    if (parts.length < 2) return false;
    final start = DateTime(now.year, now.month, now.day, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return !start.isAfter(now);
  }

  String? get _ownerPhone {
    final phone = _field?['owner']?['user']?['phone'];
    return (phone == null || '$phone'.isEmpty) ? null : '$phone';
  }

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir l'application.")));
    }
  }

  void _call() => _open(Uri(scheme: 'tel', path: _ownerPhone));

  void _whatsapp() {
    final digits = _ownerPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent('Bonjour, je vous contacte via myTerrain au sujet du terrain « ${_field?['name'] ?? ''} ».');
    _open(Uri.parse('https://wa.me/$digits?text=$text'));
  }

  // ─── Réservation ───

  Future<void> _confirmBooking(dynamic slot) async {
    final price = _slotPrice(slot);
    final day = toBeginningOfSentenceCase(DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDate));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la réservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_field?['name'] ?? 'Terrain', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$day\n${_hhmm(slot['start_time'])} – ${_hhmm(slot['end_time'])}'),
            if (price != null) ...[
              const SizedBox(height: 8),
              Text(_fcfa(price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _green)),
              const SizedBox(height: 4),
              Text('Acompte de ${_fcfa(price / 2)} à payer pour bloquer le créneau.',
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Réserver et payer')),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<BookingCubit>().bookSlot(slot['id'], 'Réservé depuis mobile');
    }
  }

  // ─── UI ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_field?['name'] ?? 'Terrain')),
      body: BlocConsumer<BookingCubit, BookingState>(
        listener: (context, state) {
          if (state is BookingSuccess) {
            // Au retour du paiement, on recharge : le créneau a pu changer de statut
            context.push('/payment', extra: state.reservation).then((_) {
              if (mounted) _fetchSlots();
            });
          } else if (state is BookingFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildPhotos()),
              SliverToBoxAdapter(child: _buildInfo()),
              SliverToBoxAdapter(child: _buildContact()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text('Créneaux', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              SliverToBoxAdapter(child: _buildDateStrip()),
              ..._buildSlots(state),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhotos() {
    final images = (_field?['images'] as List?) ?? [];
    const height = 220.0;

    if (images.isEmpty) {
      return Container(
        height: height,
        color: Colors.green.shade50,
        child: const Center(child: Icon(Icons.stadium, size: 72, color: _green)),
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _photoController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _photoIndex = i),
            itemBuilder: (_, i) => Image.network(
              '${DioClient.serverUrl}${images[i]['url']}',
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text('${_photoIndex + 1} / ${images.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    if (_fieldError != null) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(_fieldError!));
    }
    final field = _field;
    if (field == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }

    final price = _toNum(field['price_per_hour']);
    final amenities = parseAmenities(field['amenities']);
    final specs = [
      fieldTypeLabel(field['type']),
      if (field['capacity'] != null) '${field['capacity']} joueurs',
      if ((field['size'] ?? '').toString().isNotEmpty) '${field['size']}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(field['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              if (price != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fcfa(price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _green)),
                    Text('par heure', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(specs, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 4),
              Expanded(child: Text('${field['address'] ?? ''}, ${field['city'] ?? ''}')),
            ],
          ),
          if ((field['description'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${field['description']}'),
          ],
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Équipements', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: amenities
                  .map((a) => Chip(
                        label: Text(fieldAmenityLabels[a] ?? a),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContact() {
    final owner = _field?['owner'];
    if (owner == null || _ownerPhone == null) return const SizedBox();
    final name = owner['business_name'] ?? owner['user']?['name'] ?? 'Gérant';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Géré par $name', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (owner['user']?['name'] != null && owner['user']['name'] != name)
              Text('${owner['user']['name']}', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            Text(
              "L'horaire que vous voulez n'est pas proposé ? Contactez le gérant.",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.call),
                    label: const Text('Appeler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _whatsapp,
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateStrip() {
    final today = DateTime.now();
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: 30,
        itemBuilder: (context, index) {
          final date = DateTime(today.year, today.month, today.day + index);
          final selected = date == _selectedDate;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _fetchSlots();
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? _green : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? _green : Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E', 'fr_FR').format(date).replaceAll('.', ''),
                      style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : Colors.grey.shade600)),
                  Text('${date.day}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSlots(BookingState state) {
    if (state is SlotsLoading) {
      return const [
        SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
      ];
    }

    final slots = context.read<BookingCubit>().currentSlots.where((s) => !_isPast(s)).toList();
    if (slots.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('Aucun créneau ce jour-là.', style: TextStyle(color: Colors.grey.shade600)),
                if (_ownerPhone != null)
                  Text('Contactez le gérant ci-dessus pour un autre horaire.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ];
    }

    final bookingSlotId = state is BookingLoading ? state.slotId : null;

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            childCount: slots.length,
            (context, index) {
              final slot = slots[index];
              final available = slot['status'] == 'available';
              final price = _slotPrice(slot);
              final promo = slot['promo_label'];

              return Material(
                color: available ? Colors.white : Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: available ? _green : Colors.grey.shade300),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: (available && bookingSlotId == null) ? () => _confirmBooking(slot) : null,
                  child: Center(
                    child: bookingSlotId == slot['id']
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${_hhmm(slot['start_time'])} – ${_hhmm(slot['end_time'])}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: available ? Colors.black87 : Colors.grey.shade500,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                !available
                                    ? 'Indisponible'
                                    : [if (price != null) _fcfa(price), if (promo != null) '$promo'].join(' · '),
                                style: TextStyle(fontSize: 12, color: available ? _green : Colors.grey.shade500),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }
}
