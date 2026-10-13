import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/fields/presentation/pages/home_page.dart';
import '../../features/fields/presentation/pages/owner_home_page.dart';
import '../../features/booking/presentation/pages/field_detail_page.dart';
import '../../features/booking/presentation/pages/payment_page.dart';
import '../../features/booking/presentation/pages/my_reservations_page.dart';
import '../../features/fields/presentation/pages/map_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/fields/presentation/pages/favorites_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/owner/presentation/pages/owner_slots_page.dart';
import '../../features/owner/presentation/pages/owner_field_form_page.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/owner_home',
      builder: (context, state) => const OwnerHomePage(),
    ),
    GoRoute(
      path: '/field/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return FieldDetailPage(fieldId: id);
      },
    ),
    GoRoute(
      path: '/payment',
      builder: (context, state) {
        final reservation = state.extra as Map<String, dynamic>;
        return PaymentPage(reservation: reservation);
      },
    ),
    GoRoute(
      path: '/my_reservations',
      builder: (context, state) => const MyReservationsPage(),
    ),
    GoRoute(
      path: '/map',
      builder: (context, state) => const MapPage(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/owner/slots',
      builder: (context, state) => OwnerSlotsPage(field: state.extra as Map<String, dynamic>),
    ),
    GoRoute(
      path: '/owner/field/new',
      builder: (context, state) => const OwnerFieldFormPage(),
    ),
    GoRoute(
      path: '/owner/field/:id/edit',
      builder: (context, state) => OwnerFieldFormPage(fieldId: int.parse(state.pathParameters['id']!)),
    ),
  ],
);
