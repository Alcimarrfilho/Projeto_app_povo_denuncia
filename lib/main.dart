import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:projeto_app_povo_denuncia/status_denuncia.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_app_povo_denuncia/minhas_denuncias.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'redefinir_senha_screen.dart';
import 'feed_screen.dart';
import 'new_denuncia_screen.dart';
import 'conta_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu App de Denúncias',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream:
            FirebaseAuth.instance
                .authStateChanges(), // Escuta mudanças no estado de autenticação
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Mostra um indicador de carregamento enquanto verifica o estado
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // Se o usuário está logado, vai para a tela principal (Feed)
            return const FeedScreen();
          } else {
            // Se o usuário não está logado, vai para a tela de Login
            return const LoginScreen();
          }
        },
      ),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/forgot_password': (context) => const RedefinirSenhaScreen(),
        '/feed': (context) => FeedScreen(),
        '/report': (context) => const NewDenunciaScreen(),
        '/conta': (context) => const ContaScreen(),
        '/status_denuncia': (context) => const StatusDenunciaScreen(),
        '/ver_editar_denuncia': (context) => const MinhasDenuncias(),
      },
    );
  }
}
