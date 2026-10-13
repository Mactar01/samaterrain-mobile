import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_cubit.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _phone = '';
  String _password = '';
  String _passwordConfirmation = '';

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      context.read<AuthCubit>().register(_name, _email, _phone, _password, _passwordConfirmation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            context.go('/home'); // Force player routing (API forces role to player)
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add, size: 60, color: Color(0xFF2E7D32)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Rejoignez myTerrain !',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Inscrivez-vous pour réserver les meilleurs terrains.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 32),
                            
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Nom complet',
                                prefixIcon: Icon(Icons.person),
                              ),
                              onSaved: (val) => _name = val ?? '',
                              validator: (val) => val != null && val.isNotEmpty ? null : 'Veuillez entrer votre nom',
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              onSaved: (val) => _email = val ?? '',
                              validator: (val) => val != null && val.contains('@') ? null : 'Email invalide',
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Téléphone (ex: 770000000)',
                                prefixIcon: Icon(Icons.phone),
                              ),
                              keyboardType: TextInputType.phone,
                              onSaved: (val) => _phone = val ?? '',
                              validator: (val) => val != null && val.isNotEmpty ? null : 'Veuillez entrer un numéro',
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: Icon(Icons.lock),
                              ),
                              obscureText: true,
                              onChanged: (val) => _password = val,
                              onSaved: (val) => _password = val ?? '',
                              validator: (val) => val != null && val.length >= 8 ? null : 'Minimum 8 caractères',
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Confirmer mot de passe',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                              onSaved: (val) => _passwordConfirmation = val ?? '',
                              validator: (val) => val != null && val == _password ? null : 'Les mots de passe ne correspondent pas',
                            ),
                            const SizedBox(height: 32),
                            
                            ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Text('Créer mon compte', style: TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Déjà un compte ? Connectez-vous'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
