import 'package:flutter/material.dart';

class ContaScreen extends StatelessWidget {
  const ContaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minha Conta')),
      body: const Center(
        child: Text('Informações da conta e denúncias feitas.'),
      ),
    );
  }
}
