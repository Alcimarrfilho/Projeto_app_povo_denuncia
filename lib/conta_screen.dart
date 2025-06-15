import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer'; // Para usar log no lugar de print
import 'package:projeto_app_povo_denuncia/login_screen.dart';

class ContaScreen extends StatefulWidget {
  const ContaScreen({super.key});

  @override
  State<ContaScreen> createState() => _ContaScreenState();
}

class _ContaScreenState extends State<ContaScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // Para armazenar as informações do usuário logado

  @override
  void initState() {
    super.initState();
    _currentUser =
        _auth.currentUser; // Obtém o usuário logado quando a tela é iniciada
  }

  // Função para lidar com o logout do usuário
  Future<void> _logout() async {
    try {
      await _auth.signOut(); // Realiza o logout do Firebase
      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false, // Remove todas as rotas da pilha
      );
      log('Usuário deslogado com sucesso!');
    } catch (e) {
      log(
        'Erro ao deslogar: $e',
      ); // Loga qualquer erro que ocorra durante o logout
      if (!mounted) return; // Verifica se o widget ainda está montado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair da conta: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Conta'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(
          255,
          240,
          71,
          4,
        ), // Cor consistente com seu tema
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        // Permite rolagem se o conteúdo exceder a tela
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.center, // Centraliza os itens na coluna
          children: [
            // Ícone/Avatar do Usuário (como na sua captura de tela)
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey, // Cor de fundo para o avatar
              child: Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 16),
            // Texto "Informações da conta e denúncias feitas."
            const Text(
              'Informações da conta e denúncias feitas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(
              height: 32,
            ), // Espaço maior para separar o texto dos botões
            // Card com as opções
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Botão "Minhas Denúncias"
                  ListTile(
                    leading: const Icon(
                      Icons.description,
                      color: Color.fromARGB(255, 240, 71, 4),
                    ),
                    title: const Text('Minhas Denúncias'),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      // Navega para a tela de denúncias (ver/editar)
                      Navigator.pushNamed(context, '/ver_editar_denuncia');
                    },
                  ),
                  const Divider(
                    height: 0,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ), // Divisor
                  // Botão "Sair da Conta"
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Sair da Conta',
                      style: TextStyle(color: Colors.red),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: _logout, // Chama a função de logout
                  ),
                ],
              ),
            ),
            // Informações adicionais do usuário (se houver, como ID do usuário)
            const SizedBox(height: 20),
            Text(
              'ID do Usuário: ${_currentUser?.uid ?? 'Não disponível'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            // Adicione aqui outros textos ou widgets para informações adicionais se desejar.
          ],
        ),
      ),
    );
  }
}
