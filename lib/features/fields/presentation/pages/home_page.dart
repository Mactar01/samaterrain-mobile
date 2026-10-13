import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../bloc/field_cubit.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../core/network/dio_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  String _selectedType = 'Tous';
  
  // Geolocation states
  double? _currentLat;
  double? _currentLng;
  bool _isLocating = false;
  
  final List<String> _types = ['Tous', 'artificial_grass', 'natural_grass', 'futsal', 'concrete'];
  
  // Mapping pour l'affichage propre
  final Map<String, String> _typeLabels = {
    'Tous': 'Tous',
    'artificial_grass': 'Synthétique',
    'natural_grass': 'Naturel',
    'futsal': 'Futsal',
    'concrete': 'Béton'
  };

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  void _loadFields() {
    context.read<FieldCubit>().fetchFields(
      search: _searchController.text,
      city: _cityController.text,
      type: _selectedType,
      lat: _currentLat,
      lng: _currentLng,
    );
  }

  Future<void> _findNearMe() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le service de localisation est désactivé.')));
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission de localisation refusée.')));
          setState(() => _isLocating = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Les permissions sont définitivement refusées.')));
        setState(() => _isLocating = false);
        return;
      } 

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _isLocating = false;
      });
      _loadFields();
    } catch (e) {
      setState(() => _isLocating = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _clearLocation() {
    setState(() {
      _currentLat = null;
      _currentLng = null;
    });
    _loadFields();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtres'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Type de surface'),
                items: _types.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(_typeLabels[type] ?? type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _selectedType = value;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _cityController.clear();
                _selectedType = 'Tous';
                Navigator.pop(context);
                _loadFields();
              },
              child: const Text('Réinitialiser'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadFields();
              },
              child: const Text('Appliquer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terrains Disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              context.push('/map');
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.green),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person, size: 60, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Espace Joueur', style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Accueil'),
              onTap: () {
                Navigator.pop(context); // Close drawer
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
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Mes Réservations'),
              onTap: () {
                Navigator.pop(context);
                context.push('/my_reservations');
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: const Text('Mes Favoris'),
              onTap: () {
                Navigator.pop(context);
                context.push('/favorites');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
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
      body: Column(
        children: [
          // Barre de recherche et Bouton GPS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un terrain...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadFields();
                            },
                          )
                        : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Colors.green),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onSubmitted: (_) => _loadFields(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _currentLat != null ? _clearLocation : _findNearMe,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _currentLat != null ? Colors.green : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _currentLat != null ? Colors.green : Colors.grey.shade400),
                    ),
                    child: _isLocating 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _currentLat != null ? Icons.my_location : Icons.location_searching,
                          color: _currentLat != null ? Colors.white : Colors.grey.shade700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          
          // Liste
          Expanded(
            child: BlocBuilder<FieldCubit, FieldState>(
              builder: (context, state) {
                if (state is FieldLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is FieldError) {
                  return Center(child: Text(state.message));
                } else if (state is FieldLoaded) {
                  final fields = state.fields;
                  if (fields.isEmpty) {
                    return const Center(child: Text("Aucun terrain ne correspond à votre recherche."));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: fields.length,
                    itemBuilder: (context, index) {
                      final field = fields[index];
                      // Construire l'URL de l'image
                      String? imageUrl;
                      if (field['primary_image'] != null) {
                        final path = field['primary_image']['url'];
                        imageUrl = '${DioClient.serverUrl}$path';
                      }

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
                              // Image
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
                                          field['is_favorite'] == true ? Icons.favorite : Icons.favorite_border,
                                          color: field['is_favorite'] == true ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: () {
                                          context.read<FieldCubit>().toggleFavorite(field['id'], field['is_favorite'] == true);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Infos
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
                                          if (field['distance_km'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6.0),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.directions_run, size: 16, color: Colors.blue),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "à ${(field['distance_km'] as num).toStringAsFixed(1)} km",
                                                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        "${field['price_per_hour']} ${field['currency']}/h",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
          )
        ],
      ),
    );
  }
}
