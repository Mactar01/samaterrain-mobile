import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/field_cubit.dart';
import '../../data/field_options.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../owner/presentation/pages/owner_dashboard_tab.dart';
import '../../../owner/presentation/pages/owner_reservations_tab.dart';

/// Espace loueur : tableau de bord, réservations reçues, terrains (→ gestion des créneaux).
class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({Key? key}) : super(key: key);

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _tab = 0;

  static const _titles = ['Tableau de bord', 'Réservations', 'Mes Terrains'];

  @override
  void initState() {
    super.initState();
    context.read<FieldCubit>().fetchOwnerFields();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1B5E20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.business, size: 60, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Espace Loueur', style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Mon Profil'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthCubit>().logout();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          OwnerDashboardTab(),
          OwnerReservationsTab(),
          _OwnerFieldsTab(),
        ],
      ),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: () => _openFieldForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Terrain'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Réservations'),
          NavigationDestination(icon: Icon(Icons.stadium_outlined), selectedIcon: Icon(Icons.stadium), label: 'Terrains'),
        ],
      ),
    );
  }
}

/// Ouvre le formulaire terrain (création si fieldId == null) et recharge la liste au retour.
Future<void> _openFieldForm(BuildContext context, [int? fieldId]) async {
  final changed = await context.push<bool>(fieldId == null ? '/owner/field/new' : '/owner/field/$fieldId/edit');
  if (changed == true && context.mounted) {
    context.read<FieldCubit>().fetchOwnerFields();
  }
}

class _OwnerFieldsTab extends StatelessWidget {
  const _OwnerFieldsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FieldCubit, FieldState>(
      builder: (context, state) {
        if (state is FieldLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is FieldError) {
          return Center(child: Text(state.message));
        } else if (state is FieldLoaded) {
          final fields = state.fields;
          if (fields.isEmpty) {
            return const Center(child: Text("Vous n'avez aucun terrain."));
          }
          return RefreshIndicator(
            onRefresh: () => context.read<FieldCubit>().fetchOwnerFields(),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...fields.map((field) {
                  final imagePath = field['primary_image']?['url'];
                  final isActive = field['is_active'] == true || field['is_active'] == 1;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: imagePath != null
                              ? Image.network('${DioClient.serverUrl}$imagePath', fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.stadium, color: Color(0xFF2E7D32)))
                              : Container(
                                  color: Colors.green.shade50,
                                  child: const Icon(Icons.stadium, size: 32, color: Color(0xFF2E7D32)),
                                ),
                        ),
                      ),
                      title: Text(field['name'] ?? 'Inconnu', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "${field['city'] ?? ''} • ${fieldTypeLabel(field['type'])}"
                        "${isActive ? '' : '\nMasqué aux joueurs'}"
                        "\nToucher pour gérer les créneaux",
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Modifier le terrain',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openFieldForm(context, field['id']),
                      ),
                      onTap: () => context.push('/owner/slots', extra: Map<String, dynamic>.from(field)),
                    ),
                  );
                }),
                const SizedBox(height: 80),
              ],
            ),
          );
        }
        return const SizedBox();
      },
    );
  }
}
