import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/owner_repository.dart';

/// Gestion des créneaux d'un terrain par le loueur : voir, générer, ajouter, bloquer, supprimer, réserver manuellement.
class OwnerSlotsPage extends StatefulWidget {
  final Map<String, dynamic> field;

  const OwnerSlotsPage({Key? key, required this.field}) : super(key: key);

  @override
  State<OwnerSlotsPage> createState() => _OwnerSlotsPageState();
}

class _OwnerSlotsPageState extends State<OwnerSlotsPage> {
  final _repository = OwnerRepository();
  late DateTime _selectedDate;
  List<dynamic> _slots = [];
  bool _isLoading = true;
  String? _error;

  static final _apiDate = DateFormat('yyyy-MM-dd');

  int get _fieldId => widget.field['id'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final slots = await _repository.getSlots(_fieldId, _apiDate.format(_selectedDate));
      setState(() => _slots = slots);
    } catch (e) {
      setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      _showSnack(successMessage);
      await _fetch();
    } catch (e) {
      _showSnack(_clean(e), error: true);
    }
  }

  static String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _short(dynamic time) => '${time ?? ''}'.length >= 5 ? '$time'.substring(0, 5) : '${time ?? ''}';

  num? _priceOf(dynamic slot) {
    for (final v in [slot['promo_price'], slot['price'], widget.field['price_per_hour']]) {
      final n = v is num ? v : num.tryParse('${v ?? ''}');
      if (n != null) return n;
    }
    return null;
  }

  // ─── Actions sur un créneau ───

  /// Les comptes sont enregistrés en "+221XXXXXXXXX" : « 77 123 45 67 » doit retrouver le même joueur.
  static String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.startsWith('00')) return '+${digits.substring(2)}';
    if (digits.length == 9) return '+221$digits';
    return digits;
  }

  Future<void> _manualReservation(dynamic slot) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Réserver ${_short(slot['start_time'])} - ${_short(slot['end_time'])}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pour un client qui a réservé par téléphone ou sur place. La réservation sera directement confirmée.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom du joueur'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Téléphone requis' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Réserver'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _run(
        () => _repository.createManualReservation(slot['id'], nameController.text.trim(), _normalizePhone(phoneController.text)),
        'Réservation enregistrée.',
      );
    }
  }

  Future<void> _deleteSlot(dynamic slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce créneau ?'),
        content: Text('${_short(slot['start_time'])} - ${_short(slot['end_time'])}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _repository.deleteSlot(_fieldId, slot['id']), 'Créneau supprimé.');
    }
  }

  // ─── Création de créneaux ───

  void _openAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Générer plusieurs créneaux'),
              subtitle: const Text('Ex : tous les jours de 08:00 à 23:00, par tranches d\'1 h'),
              onTap: () {
                Navigator.pop(ctx);
                _openBulkDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Ajouter un seul créneau'),
              subtitle: Text('Le ${DateFormat('d MMMM', 'fr_FR').format(_selectedDate)}'),
              onTap: () {
                Navigator.pop(ctx);
                _openSingleDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBulkDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _BulkSlotsDialog(
        initialDate: _selectedDate,
        defaultPrice: _priceOf({}),
        onSubmit: (data) => _repository.bulkCreateSlots(
          _fieldId,
          startDate: _apiDate.format(data.range.start),
          endDate: _apiDate.format(data.range.end),
          startTime: _hhmm(data.start),
          endTime: _hhmm(data.end),
          durationMinutes: data.durationMinutes,
          price: data.price,
        ),
      ),
    );
    if (result != null) {
      _showSnack(result);
      await _fetch();
    }
  }

  Future<void> _openSingleDialog() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Heure de début',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute),
      helpText: 'Heure de fin',
    );
    if (end == null) return;

    await _run(
      () => _repository.createSlot(
        _fieldId,
        date: _apiDate.format(_selectedDate),
        startTime: _hhmm(start),
        endTime: _hhmm(end),
      ),
      'Créneau ajouté.',
    );
  }

  // ─── UI ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.field['name'] ?? 'Créneaux')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Créneaux'),
      ),
      body: Column(
        children: [
          _buildDateStrip(),
          const Divider(height: 1),
          Expanded(child: _buildSlots()),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    final today = DateTime.now();
    final days = List.generate(30, (i) => DateTime(today.year, today.month, today.day + i));

    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = day == _selectedDate;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _fetch();
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2E7D32) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? const Color(0xFF2E7D32) : Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E', 'fr_FR').format(day),
                      style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : Colors.grey)),
                  Text('${day.day}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlots() {
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
    if (_slots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun créneau ce jour-là.\nAppuyez sur « Créneaux » pour en générer.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _slots.length,
        itemBuilder: (context, index) {
          final slot = _slots[index];
          final status = slot['status'];
          final price = _priceOf(slot);

          final (Color color, String label) = switch (status) {
            'available' => (Colors.green, 'Libre'),
            'reserved' => (Colors.blue, 'Réservé'),
            'blocked' => (Colors.grey, 'Bloqué'),
            _ => (Colors.grey, '$status'),
          };

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Icon(Icons.schedule, color: color),
              title: Text('${_short(slot['start_time'])} - ${_short(slot['end_time'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text([
                if (price != null) '${price.round()} FCFA',
                if (slot['promo_label'] != null) '🏷 ${slot['promo_label']}',
                if (status == 'blocked' && slot['block_reason'] != null) slot['block_reason'],
              ].join(' • ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  if (status != 'reserved')
                    PopupMenuButton<String>(
                      onSelected: (action) {
                        switch (action) {
                          case 'manual':
                            _manualReservation(slot);
                          case 'block':
                            _run(() => _repository.setSlotBlocked(_fieldId, slot['id'], true), 'Créneau bloqué.');
                          case 'unblock':
                            _run(() => _repository.setSlotBlocked(_fieldId, slot['id'], false), 'Créneau débloqué.');
                          case 'delete':
                            _deleteSlot(slot);
                        }
                      },
                      itemBuilder: (_) => [
                        if (status == 'available') ...const [
                          PopupMenuItem(value: 'manual', child: Text('Réserver pour un client')),
                          PopupMenuItem(value: 'block', child: Text('Bloquer')),
                          PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
                        ],
                        if (status == 'blocked') const PopupMenuItem(value: 'unblock', child: Text('Débloquer')),
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

class _BulkSlotsData {
  final DateTimeRange range;
  final TimeOfDay start;
  final TimeOfDay end;
  final int durationMinutes;
  final double? price;

  _BulkSlotsData(this.range, this.start, this.end, this.durationMinutes, this.price);
}

/// Formulaire de génération en lot. Se ferme en renvoyant le message du serveur en cas de succès.
class _BulkSlotsDialog extends StatefulWidget {
  final DateTime initialDate;
  final num? defaultPrice;
  final Future<String> Function(_BulkSlotsData data) onSubmit;

  const _BulkSlotsDialog({required this.initialDate, required this.defaultPrice, required this.onSubmit});

  @override
  State<_BulkSlotsDialog> createState() => _BulkSlotsDialogState();
}

class _BulkSlotsDialogState extends State<_BulkSlotsDialog> {
  late DateTimeRange _range;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 23, minute: 0);
  int _duration = 60;
  final _priceController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  static final _display = DateFormat('d MMM', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _range = DateTimeRange(start: widget.initialDate, end: widget.initialDate.add(const Duration(days: 6)));
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final price = double.tryParse(_priceController.text.trim());
      final message = await widget.onSubmit(_BulkSlotsData(_range, _start, _end, _duration, price));
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Générer des créneaux'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range),
              title: const Text('Période'),
              subtitle: Text('Du ${_display.format(_range.start)} au ${_display.format(_range.end)}'),
              onTap: _pickRange,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('De'),
                    subtitle: Text(_OwnerSlotsPageState._hhmm(_start)),
                    onTap: () => _pickTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('À'),
                    subtitle: Text(_OwnerSlotsPageState._hhmm(_end)),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'Durée d\'un créneau'),
              items: const [
                DropdownMenuItem(value: 60, child: Text('1 h')),
                DropdownMenuItem(value: 90, child: Text('1 h 30')),
                DropdownMenuItem(value: 120, child: Text('2 h')),
              ],
              onChanged: (v) => setState(() => _duration = v ?? 60),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Prix (FCFA, optionnel)',
                hintText: widget.defaultPrice != null ? 'Par défaut : ${widget.defaultPrice!.round()}' : null,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Les créneaux qui existent déjà ne sont pas dupliqués.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Générer'),
        ),
      ],
    );
  }
}
