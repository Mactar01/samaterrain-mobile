import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/dio_client.dart';
import '../../../fields/data/field_options.dart';
import '../../data/owner_repository.dart';

/// Création (fieldId == null) ou modification d'un terrain, avec ses photos.
/// Se ferme en renvoyant `true` si quelque chose a changé.
class OwnerFieldFormPage extends StatefulWidget {
  final int? fieldId;

  const OwnerFieldFormPage({Key? key, this.fieldId}) : super(key: key);

  @override
  State<OwnerFieldFormPage> createState() => _OwnerFieldFormPageState();
}

class _OwnerFieldFormPageState extends State<OwnerFieldFormPage> {
  final _repository = OwnerRepository();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Dakar');
  final _capacity = TextEditingController(text: '10');
  final _size = TextEditingController();
  final _price = TextEditingController();

  String _type = 'artificial_grass';
  final Set<String> _amenities = {};
  bool _isActive = true;
  double? _latitude;
  double? _longitude;

  /// Photos déjà en ligne (mode modification) : {id, url, is_primary}
  List<dynamic> _images = [];

  /// Photos choisies sur le téléphone, envoyées à l'enregistrement
  final List<XFile> _newImages = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isLocating = false;
  bool _changed = false;

  bool get _isEdit => widget.fieldId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _address, _city, _capacity, _size, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  double? _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final field = await _repository.getField(widget.fieldId!);
      setState(() {
        _name.text = field['name'] ?? '';
        _description.text = field['description'] ?? '';
        _address.text = field['address'] ?? '';
        _city.text = field['city'] ?? '';
        _capacity.text = '${field['capacity'] ?? ''}';
        _size.text = field['size'] ?? '';
        _price.text = '${_toDouble(field['price_per_hour'])?.round() ?? ''}';
        if (fieldTypeLabels.containsKey(field['type'])) _type = field['type'];
        _isActive = field['is_active'] == true || field['is_active'] == 1;
        _latitude = _toDouble(field['latitude']);
        _longitude = _toDouble(field['longitude']);
        _amenities
          ..clear()
          ..addAll(parseAmenities(field['amenities']));
        _images = (field['images'] as List?) ?? [];
      });
    } catch (e) {
      _showSnack(_clean(e), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Localisation ───

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activez la localisation du téléphone.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation refusée.');
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      _showSnack(_clean(e), error: true);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // ─── Photos ───

  Future<void> _pickImages() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Compression pour rester sous la limite de 5 Mo du serveur
    const maxWidth = 1600.0;
    const quality = 80;
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(maxWidth: maxWidth, imageQuality: quality);
      setState(() => _newImages.addAll(picked));
    } else {
      final picked = await _picker.pickImage(source: source, maxWidth: maxWidth, imageQuality: quality);
      if (picked != null) setState(() => _newImages.add(picked));
    }
  }

  Future<void> _deleteImage(dynamic image) async {
    try {
      await _repository.deleteFieldImage(widget.fieldId!, image['id']);
      _changed = true;
      await _load();
    } catch (e) {
      _showSnack(_clean(e), error: true);
    }
  }

  Future<void> _setPrimary(dynamic image) async {
    try {
      await _repository.setPrimaryImage(widget.fieldId!, image['id']);
      _changed = true;
      await _load();
    } catch (e) {
      _showSnack(_clean(e), error: true);
    }
  }

  // ─── Enregistrement ───

  Map<String, dynamic> _payload() => {
        'name': _name.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'type': _type,
        'capacity': int.parse(_capacity.text.trim()),
        'size': _size.text.trim().isEmpty ? null : _size.text.trim(),
        'price_per_hour': double.parse(_price.text.trim()),
        'amenities': _amenities.toList(),
        'is_active': _isActive,
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    int? fieldId = widget.fieldId;
    try {
      if (_isEdit) {
        await _repository.updateField(fieldId!, _payload());
      } else {
        fieldId = await _repository.createField(_payload());
      }
      _changed = true;

      // Photos : la première devient principale s'il n'y en a pas encore
      final hasPrimary = _images.any((i) => i['is_primary'] == true || i['is_primary'] == 1);
      for (var i = 0; i < _newImages.length; i++) {
        await _repository.uploadFieldImage(fieldId, _newImages[i].path, isPrimary: !hasPrimary && i == 0);
      }

      if (!mounted) return;
      _showSnack(_isEdit ? 'Terrain mis à jour.' : 'Terrain créé. Pensez à générer ses créneaux.');
      Navigator.of(context).pop(true);
    } catch (e) {
      // Terrain créé mais une photo a échoué : on passe en modification pour pouvoir réessayer
      if (!_isEdit && fieldId != null) {
        _showSnack('Terrain créé, mais une photo n\'a pas pu être envoyée : ${_clean(e)}', error: true);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      _showSnack(_clean(e), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── UI ───

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Modifier le terrain' : 'Nouveau terrain'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _section('Photos'),
                    _buildPhotos(),
                    _section('Informations'),
                    TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nom du terrain *'), validator: _required),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type de surface *'),
                      items: fieldTypeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (v) => setState(() => _type = v ?? _type),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Prix / heure (FCFA) *'),
                            validator: (v) => double.tryParse(v?.trim() ?? '') == null ? 'Nombre requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _capacity,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Joueurs max *'),
                            validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) < 2 ? 'Minimum 2' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _size, decoration: const InputDecoration(labelText: 'Dimensions (ex : 40x20m)')),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    _section('Adresse'),
                    TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Adresse *'), validator: _required),
                    const SizedBox(height: 12),
                    TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Ville *'), validator: _required),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on),
                      title: Text(_latitude == null
                          ? 'Position GPS non définie'
                          : 'Position : ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'),
                      subtitle: const Text('Pour apparaître sur la carte et dans « terrains proches »'),
                      trailing: _isLocating
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(onPressed: _useCurrentLocation, child: const Text('Ma position')),
                    ),
                    _section('Équipements'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: fieldAmenityLabels.entries
                          .map((e) => FilterChip(
                                label: Text(e.value),
                                selected: _amenities.contains(e.key),
                                onSelected: (on) => setState(() => on ? _amenities.add(e.key) : _amenities.remove(e.key)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Visible par les joueurs'),
                      subtitle: const Text('Décochez pour retirer le terrain sans perdre son historique'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEdit ? 'Enregistrer' : 'Créer le terrain'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );

  Widget _buildPhotos() {
    final tiles = <Widget>[
      ..._images.map((img) {
        final isPrimary = img['is_primary'] == true || img['is_primary'] == 1;
        return _PhotoTile(
          image: Image.network('${DioClient.serverUrl}${img['url']}', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
          isPrimary: isPrimary,
          onSetPrimary: isPrimary ? null : () => _setPrimary(img),
          onDelete: () => _deleteImage(img),
        );
      }),
      ..._newImages.map((file) => _PhotoTile(
            image: Image.file(File(file.path), fit: BoxFit.cover),
            pendingLabel: 'À envoyer',
            onDelete: () => setState(() => _newImages.remove(file)),
          )),
      InkWell(
        onTap: _pickImages,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(Icons.add_a_photo), SizedBox(height: 4), Text('Ajouter')],
          ),
        ),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: tiles,
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Widget image;
  final bool isPrimary;
  final String? pendingLabel;
  final VoidCallback? onSetPrimary;
  final VoidCallback onDelete;

  const _PhotoTile({
    required this.image,
    required this.onDelete,
    this.isPrimary = false,
    this.pendingLabel,
    this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (isPrimary || pendingLabel != null)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Text(isPrimary ? 'Principale' : pendingLabel!, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              children: [
                if (onSetPrimary != null)
                  _iconButton(Icons.star_border, 'Mettre en principale', onSetPrimary!),
                _iconButton(Icons.close, 'Retirer', onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 16, color: Colors.white)),
          ),
        ),
      );
}
