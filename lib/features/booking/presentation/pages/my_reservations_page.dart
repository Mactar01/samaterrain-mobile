import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/booking_cubit.dart';

import 'package:qr_flutter/qr_flutter.dart';

class MyReservationsPage extends StatefulWidget {
  const MyReservationsPage({Key? key}) : super(key: key);

  @override
  State<MyReservationsPage> createState() => _MyReservationsPageState();
}

class _MyReservationsPageState extends State<MyReservationsPage> {
  @override
  void initState() {
    super.initState();
    context.read<BookingCubit>().fetchMyReservations();
  }

  void _showTicketModal(BuildContext context, dynamic reservation, dynamic field, dynamic timeSlot) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Le contenu du QR code sera l'ID de la réservation. Le gérant pourra le scanner avec son application.
        final qrData = 'reservation_${reservation['id']}';
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Votre Billet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(field['name'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Text('📅 ${timeSlot['date']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('🕒 ${timeSlot['start_time']} - ${timeSlot['end_time']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context, dynamic reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation ?'),
        content: const Text('Le créneau sera libéré pour les autres joueurs.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Oui, annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await context.read<BookingCubit>().cancelReservation(reservation['id']);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Réservation annulée.'),
      backgroundColor: error == null ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Réservations'),
        // Si on arrive ici sans page précédente, on propose quand même un retour à l'accueil
        leading: context.canPop()
            ? null
            : IconButton(
                tooltip: 'Accueil',
                icon: const Icon(Icons.home),
                onPressed: () => context.go('/home'),
              ),
      ),
      body: BlocBuilder<BookingCubit, BookingState>(
        buildWhen: (previous, current) => current is ReservationsLoading || current is ReservationsLoaded,
        builder: (context, state) {
          if (state is ReservationsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ReservationsLoaded) {
            final res = state.reservations;
            if (res.isEmpty) {
              return const Center(child: Text("Vous n'avez aucune réservation."));
            }

            return ListView.builder(
              itemCount: res.length,
              itemBuilder: (context, index) {
                final r = res[index];
                final field = r['field'];
                final timeSlot = r['time_slot'];
                final status = r['status'];
                
                Color statusColor = Colors.grey;
                String statusLabel = 'Inconnu';
                
                if (status == 'pending') {
                  statusColor = Colors.orange;
                  statusLabel = 'En attente de paiement';
                } else if (status == 'confirmed') {
                  statusColor = Colors.green;
                  statusLabel = 'Confirmée';
                } else if (status == 'cancelled') {
                  statusColor = Colors.red;
                  statusLabel = 'Annulée';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(field['name'] ?? 'Terrain inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date : ${timeSlot['date']}'),
                        Text('Heure : ${timeSlot['start_time']} - ${timeSlot['end_time']}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            if (status != 'cancelled') ...[
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                                onPressed: () => _confirmCancel(context, r),
                                child: const Text('Annuler', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: status == 'pending'
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            onPressed: () {
                              context.push('/payment', extra: r);
                            },
                            child: const Text('Payer', style: TextStyle(color: Colors.white)),
                          )
                        : (status == 'confirmed' 
                            ? IconButton(
                                icon: const Icon(Icons.qr_code_2, size: 36, color: Colors.black87),
                                onPressed: () => _showTicketModal(context, r, field, timeSlot),
                              )
                            : Text("${r['total_price']} FCFA", style: const TextStyle(fontWeight: FontWeight.bold))),
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
