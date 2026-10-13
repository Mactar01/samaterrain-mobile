import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';
import '../bloc/booking_cubit.dart';

/// Paiement d'une réservation en attente : acompte (50 %), totalité ou montant libre,
/// via Wave ou Orange Money (seuls moyens gérés par le backend).
class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> reservation;
  const PaymentPage({Key? key, required this.reservation}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

enum _AmountOption { half, full, custom }

class _PaymentPageState extends State<PaymentPage> {
  static const _green = Color(0xFF2E7D32);
  static final _money = NumberFormat.decimalPattern('fr_FR');

  _AmountOption _option = _AmountOption.half;
  String _method = 'wave';
  final _phoneController = TextEditingController();
  final _customController = TextEditingController();

  Map<String, dynamic> get _slot =>
      Map<String, dynamic>.from(widget.reservation['time_slot'] ?? widget.reservation['timeSlot'] ?? {});

  double get _total => double.tryParse('${widget.reservation['total_price']}') ?? 0;
  double get _minimum => _total / 2;

  double? get _customAmount => double.tryParse(_customController.text.replaceAll(' ', ''));

  double get _amountNow => switch (_option) {
        _AmountOption.half => _minimum,
        _AmountOption.full => _total,
        _AmountOption.custom => (_customAmount ?? _minimum).clamp(_minimum, _total).toDouble(),
      };

  String? get _customError {
    if (_option != _AmountOption.custom) return null;
    final v = _customAmount;
    if (v == null) return 'Saisissez un montant';
    if (v < _minimum) return 'Minimum ${_fcfa(_minimum)}';
    if (v > _total) return 'Maximum ${_fcfa(_total)}';
    return null;
  }

  String _fcfa(num v) => '${_money.format(v.round())} FCFA';

  @override
  void initState() {
    super.initState();
    _customController.text = _minimum.round().toString();
    _prefillPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _customController.dispose();
    super.dispose();
  }

  Future<void> _prefillPhone() async {
    try {
      final response = await DioClient().dio.get('/auth/me');
      final phone = '${response.data['phone'] ?? ''}'.replaceFirst('+221', '').trim();
      if (mounted && phone.isNotEmpty && _phoneController.text.isEmpty) {
        setState(() => _phoneController.text = phone);
      }
    } catch (_) {
      // Pas bloquant : le joueur saisit son numéro.
    }
  }

  void _submit() {
    final phone = _phoneController.text.replaceAll(' ', '');
    if (phone.length < 9) {
      _snack('Saisissez le numéro ${_method == 'wave' ? 'Wave' : 'Orange Money'} à débiter.');
      return;
    }
    if (_customError != null) {
      _snack(_customError!);
      return;
    }
    context.read<BookingCubit>().pay(
          widget.reservation['id'],
          _method,
          phone,
          _option.name,
          customAmount: _option == _AmountOption.custom ? _amountNow : null,
        );
  }

  void _snack(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String _slotLabel() {
    final date = DateTime.tryParse('${_slot['date'] ?? ''}');
    String hhmm(dynamic t) => '${t ?? ''}'.length >= 5 ? '$t'.substring(0, 5) : '${t ?? ''}';
    final day = date == null ? '' : toBeginningOfSentenceCase(DateFormat('EEEE d MMMM', 'fr_FR').format(date)) ?? '';
    return '$day · ${hhmm(_slot['start_time'])} – ${hhmm(_slot['end_time'])}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingCubit, BookingState>(
      listener: (context, state) async {
        if (state is PaymentRedirect) {
          final opened = await launchUrl(Uri.parse(state.url), mode: LaunchMode.externalApplication);
          if (!context.mounted) return;
          if (!opened) {
            _snack("Impossible d'ouvrir la page de paiement.");
            return;
          }
          _snack('Validez le paiement dans l\'application, puis revenez ici.', color: _green);
          // Accueil > Mes réservations : la flèche retour ramène à l'accueil
          final router = GoRouter.of(context);
          router.go('/home');
          router.push('/my_reservations');
        } else if (state is PaymentFailure) {
          _snack(state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is PaymentLoading;

        return Scaffold(
          appBar: AppBar(title: const Text('Paiement')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildSummary(),
              const SizedBox(height: 24),
              _title('Montant à payer maintenant'),
              _amountTile(_AmountOption.half, 'Acompte (50 %)', _fcfa(_minimum)),
              _amountTile(_AmountOption.full, 'Totalité', _fcfa(_total)),
              _amountTile(_AmountOption.custom, 'Autre montant', 'Entre ${_fcfa(_minimum)} et ${_fcfa(_total)}'),
              if (_option == _AmountOption.custom)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Montant',
                      suffixText: 'FCFA',
                      errorText: _customError,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _title('Payer avec'),
              _methodTile('wave', 'Wave', const Color(0xFF1DC8F2)),
              _methodTile('orange_money', 'Orange Money', const Color(0xFFFF7900)),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro ${_method == 'wave' ? 'Wave' : 'Orange Money'}',
                  prefixText: '+221 ',
                  hintText: '77 123 45 67',
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_total - _amountNow > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Reste à régler sur place : ${_fcfa(_total - _amountNow)}',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Payer ${_fcfa(_amountNow)}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.reservation['field']?['name'] ?? 'Terrain',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_slotLabel(), style: TextStyle(color: Colors.grey.shade700)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Prix du créneau'),
                Text(_fcfa(_total), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _amountTile(_AmountOption value, String title, String subtitle) {
    return RadioListTile<_AmountOption>(
      value: value,
      groupValue: _option,
      onChanged: (v) => setState(() => _option = v!),
      title: Text(title),
      subtitle: Text(subtitle),
      activeColor: _green,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _methodTile(String value, String label, Color brand) {
    return RadioListTile<String>(
      value: value,
      groupValue: _method,
      onChanged: (v) => setState(() => _method = v!),
      title: Text(label),
      secondary: CircleAvatar(
        radius: 16,
        backgroundColor: brand,
        child: Text(label[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      activeColor: _green,
      contentPadding: EdgeInsets.zero,
    );
  }
}
