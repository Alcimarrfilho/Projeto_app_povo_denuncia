import 'package:flutter/material.dart';

class NewDenunciaScreen extends StatefulWidget {
  const NewDenunciaScreen({super.key});

  @override
  State<NewDenunciaScreen> createState() => _NewDenunciaScreenState();
}

class _NewDenunciaScreenState extends State<NewDenunciaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  void _enviarDenuncia() {
    if (_formKey.currentState!.validate()) {
      // Aqui você pode salvar no banco de dados ou Firebase
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denúncia enviada com sucesso!')),
      );
      Navigator.pop(context); // Volta para a tela anterior
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Denúncia'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator:
                    (value) => value!.isEmpty ? 'Digite um título' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 4,
                validator:
                    (value) => value!.isEmpty ? 'Digite uma descrição' : null,
              ),
              const SizedBox(height: 48),
              Center(
                child: ElevatedButton(
                  onPressed: _enviarDenuncia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEBDCF9),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Criar Denúncia',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
