import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/field_cubit.dart';
import '../../../../core/network/dio_client.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final Map<String, String> _typeLabels = {
    'artificial_grass': 'Synthétique',
    'natural_grass': 'Naturel',
    'futsal': 'Futsal',
    'concrete': 'Béton'
  };

  @override
  void initState() {
    super.initState();
    context.read<FieldCubit>().fetchFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris'),
      ),
      body: BlocBuilder<FieldCubit, FieldState>(
        builder: (context, state) {
          if (state is FieldLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is FieldError) {
            return Center(child: Text(state.message));
          } else if (state is FieldLoaded) {
            final fields = state.fields;
            if (fields.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Aucun favori pour le moment.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: fields.length,
              itemBuilder: (context, index) {
                final field = fields[index];
                String? imageUrl;
                if (field['primary_image'] != null) {
                  final path = field['primary_image']['url'];
                  imageUrl = '${DioClient.serverUrl}$path';
                }

                // Pour les favoris, on force is_favorite à true pour l'affichage (car ce sont les favoris)
                // mais field_cubit gère déjà la propriété is_favorite
                final isFav = field['is_favorite'] ?? true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 20.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      context.push('/field/${field['id']}');
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                ),
                                child: imageUrl != null 
                                  ? Image.network(
                                      imageUrl, 
                                      fit: BoxFit.cover,
                                      headers: const {'Bypass-Tunnel-Reminder': 'true'},
                                      errorBuilder: (c, e, s) => const Icon(Icons.sports_soccer, size: 80, color: Colors.grey)
                                    )
                                  : const Icon(Icons.sports_soccer, size: 80, color: Colors.grey),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.red : Colors.grey,
                                  ),
                                  onPressed: () {
                                    context.read<FieldCubit>().toggleFavorite(field['id'], isFav);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      field['name'] ?? 'Inconnu', 
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            "${field['city']} • ${_typeLabels[field['type']] ?? field['type']}",
                                            style: const TextStyle(color: Colors.grey),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${field['price_per_hour']} FCFA",
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  const Text("par heure", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
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
