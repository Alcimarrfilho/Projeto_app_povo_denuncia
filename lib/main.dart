import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:projeto_app_povo_denuncia/status_denuncia.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'cadastro_screen.dart';
import 'redefinir_senha_screen.dart';
import 'feed_screen.dart';
import 'new_denuncia_screen.dart';
import 'conta_screen.dart';
import 'minhas_denuncias.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot_password': (context) => const RedefinirSenhaScreen(),
        '/feed': (context) => FeedScreen(),
        '/new_denuncia': (context) => const NewDenunciaScreen(),
        '/conta': (context) => const ContaScreen(),
        '/status_denuncia': (context) => const StatusDenuncia(),
        '/minhas_denuncias': (context) => const MinhasDenuncias(),
      },
    );
  }
}
