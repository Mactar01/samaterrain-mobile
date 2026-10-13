import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/booking_repository.dart';

abstract class BookingState {}
class BookingInitial extends BookingState {}
class SlotsLoading extends BookingState {}
class SlotsLoaded extends BookingState {
  final List<dynamic> slots;
  final String selectedDate;
  SlotsLoaded(this.slots, this.selectedDate);
}
class BookingLoading extends BookingState {
  final int? slotId;
  BookingLoading([this.slotId]);
}
class BookingSuccess extends BookingState {
  final Map<String, dynamic> reservation;
  BookingSuccess(this.reservation);
}
class BookingFailure extends BookingState {
  final String message;
  BookingFailure(this.message);
}
class PaymentLoading extends BookingState {}
class PaymentSuccess extends BookingState {}
class PaymentRedirect extends BookingState {
  final String url;
  PaymentRedirect(this.url);
}
class PaymentFailure extends BookingState {
  final String message;
  PaymentFailure(this.message);
}
class ReservationsLoaded extends BookingState {
  final List<dynamic> reservations;
  ReservationsLoaded(this.reservations);
}
class ReservationsLoading extends BookingState {}

class BookingCubit extends Cubit<BookingState> {
  final BookingRepository repository;
  String? currentDate;
  List<dynamic> currentSlots = [];

  BookingCubit(this.repository) : super(BookingInitial());

  Future<void> fetchSlots(int fieldId, String date) async {
    currentDate = date;
    emit(SlotsLoading());
    try {
      final slots = await repository.getSlots(fieldId, date);
      currentSlots = slots;
      emit(SlotsLoaded(slots, date));
    } catch (e) {
      emit(BookingFailure("Impossible de charger les créneaux."));
    }
  }

  Future<void> bookSlot(int slotId, String notes) async {
    emit(BookingLoading(slotId));
    try {
      final reservation = await repository.bookSlot(slotId, notes);
      if (reservation != null) {
        emit(BookingSuccess(reservation));
      } else {
        emit(BookingFailure("Erreur serveur : réponse invalide."));
        if (currentDate != null) {
          emit(SlotsLoaded(currentSlots, currentDate!));
        }
      }
    } catch (e) {
      emit(BookingFailure(e.toString().replaceAll("Exception: ", "")));
      // Re-emit les créneaux pour que l'UI se réaffiche
      if (currentDate != null) {
        emit(SlotsLoaded(currentSlots, currentDate!));
      }
    }
  }

  Future<void> pay(int reservationId, String method, String phone, String paymentType, {double? customAmount}) async {
    emit(PaymentLoading());
    try {
      final url = await repository.payReservation(reservationId, method, phone, paymentType, customAmount: customAmount);
      if (url != null) {
        emit(PaymentRedirect(url));
      } else {
        emit(PaymentFailure("Le paiement a échoué. Veuillez réessayer."));
      }
    } catch (e) {
      emit(PaymentFailure(e.toString().replaceAll("Exception: ", "")));
    }
  }

  /// Annule la réservation puis recharge la liste. Renvoie un message d'erreur, ou null si OK.
  Future<String?> cancelReservation(int reservationId) async {
    try {
      await repository.cancelReservation(reservationId);
      await fetchMyReservations();
      return null;
    } catch (e) {
      return e.toString().replaceAll("Exception: ", "");
    }
  }

  Future<void> fetchMyReservations() async {
    emit(ReservationsLoading());
    final res = await repository.getMyReservations();
    emit(ReservationsLoaded(res));
  }
}

