import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/field_repository.dart';

abstract class FieldState {}
class FieldInitial extends FieldState {}
class FieldLoading extends FieldState {}
class FieldLoaded extends FieldState {
  final List<dynamic> fields;
  FieldLoaded(this.fields);
}
class FieldError extends FieldState {
  final String message;
  FieldError(this.message);
}

class FieldCubit extends Cubit<FieldState> {
  final FieldRepository repository;

  FieldCubit(this.repository) : super(FieldInitial());

  Future<void> fetchFields({String? search, String? city, String? type, double? lat, double? lng, int? radius}) async {
    emit(FieldLoading());
    try {
      final fields = await repository.getFields(
        search: search,
        city: city,
        type: type,
        lat: lat,
        lng: lng,
        radius: radius,
      );
      emit(FieldLoaded(fields));
    } catch (e) {
      emit(FieldError("Erreur lors du chargement des terrains."));
    }
  }

  Future<void> fetchOwnerFields() async {
    emit(FieldLoading());
    try {
      final fields = await repository.getOwnerFields();
      emit(FieldLoaded(fields));
    } catch (e) {
      emit(FieldError("Erreur lors du chargement de vos terrains."));
    }
  }

  Future<void> fetchFavorites() async {
    emit(FieldLoading());
    try {
      final fields = await repository.getFavorites();
      emit(FieldLoaded(fields));
    } catch (e) {
      emit(FieldError("Erreur lors du chargement de vos favoris."));
    }
  }

  Future<void> toggleFavorite(int fieldId, bool isFavorite) async {
    if (state is FieldLoaded) {
      final currentFields = (state as FieldLoaded).fields;
      try {
        if (isFavorite) {
          await repository.removeFavorite(fieldId);
        } else {
          await repository.addFavorite(fieldId);
        }
        
        // Mettre à jour la liste localement pour éviter de recharger
        final updatedFields = currentFields.map((f) {
          if (f['id'] == fieldId) {
            return {...f, 'is_favorite': !isFavorite};
          }
          return f;
        }).toList();
        
        emit(FieldLoaded(updatedFields));
      } catch (e) {
        // En cas d'erreur, on ne fait rien pour l'instant
      }
    }
  }
}
