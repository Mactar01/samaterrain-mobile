import 'dart:convert';

/// Valeurs acceptées par l'API (StoreFieldRequest) et leurs libellés affichés.
const Map<String, String> fieldTypeLabels = {
  'artificial_grass': 'Synthétique',
  'natural_grass': 'Naturel',
  'futsal': 'Futsal',
  'concrete': 'Béton',
  'beach': 'Beach soccer',
};

/// Équipements proposés dans le formulaire terrain (stockés tels quels dans `amenities`).
const Map<String, String> fieldAmenityLabels = {
  'douche': 'Douches',
  'vestiaire': 'Vestiaires',
  'eclairage': 'Éclairage',
  'parking': 'Parking',
  'buvette': 'Buvette',
  'wifi': 'Wi-Fi',
};

String fieldTypeLabel(dynamic type) => fieldTypeLabels[type] ?? '${type ?? ''}';

/// `amenities` arrive en liste, ou en texte JSON pour les terrains de démo (double encodage du seeder).
List<String> parseAmenities(dynamic raw) {
  var value = raw;
  for (var i = 0; i < 2 && value is String; i++) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return [];
    }
  }
  return value is List ? value.map((a) => '$a').toList() : [];
}
