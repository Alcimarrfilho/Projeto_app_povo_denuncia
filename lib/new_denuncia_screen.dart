import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Importação essencial para o Firebase Auth

class NewDenunciaScreen extends StatefulWidget {
  const NewDenunciaScreen({super.key});

  @override
  State<NewDenunciaScreen> createState() => _NewDenunciaScreenState();
}

class _NewDenunciaScreenState extends State<NewDenunciaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  File? _imagem;
  // REMOVIDO: String? _imagemUrl; // Esta variável não é mais necessária aqui
  Position? _localizacao;
  String?
  _tipoDenunciaSelecionado; // <--- Variável de estado para o tipo de denúncia

  // Lista de tipos de denúncia para o Dropdown
  final List<String> _tiposDenuncia = [
    'Abandono',
    'Buraco',
    'Poluição',
    'Estupro',
    'Outros',
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.camera);

    if (foto != null) {
      setState(() {
        _imagem = File(foto.path);
      });
    }
  }

  Future<void> _pegarLocalizacao() async {
    // Adicionado if (!mounted) return; para evitar erros de contexto
    if (!mounted) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return; // Verificação adicional de mounted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative a localização no dispositivo')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return; // Verificação adicional de mounted
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return; // Verificação adicional de mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permissão de localização negada. Não foi possível obter a localização.',
            ),
          ),
        );
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.high, // Maior precisão para localização
      );
      if (!mounted) return; // Verificação adicional de mounted
      setState(() {
        _localizacao = position;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Localização obtida com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return; // Verificação adicional de mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter localização: ${e.toString()}')),
      );
      print('Erro ao obter localização: $e');
    }
  }

  Future<void> _enviarDenuncia() async {
    // Adicionado if (!mounted) return; no início
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
      // Validação para o tipo de denúncia
      if (_tipoDenunciaSelecionado == null ||
          _tipoDenunciaSelecionado!.isEmpty) {
        if (!mounted) return; // Verificação adicional de mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione o tipo de denúncia.'),
          ),
        );
        return;
      }

      // Obter o usuário atual
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return; // Verificação adicional de mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Você precisa estar logado para enviar uma denúncia.',
            ),
          ),
        );
        // Opcional: Redirecionar para tela de login, se o fluxo do seu app permitir
        // Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      try {
        String? imagemUrl;
        if (_imagem != null) {
          final ref = FirebaseStorage.instance.ref(
            'denuncias/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await ref.putFile(_imagem!);
          imagemUrl = await ref.getDownloadURL();
        }

        await FirebaseFirestore.instance.collection('denuncias').add({
          'titulo': _tituloController.text.trim(),
          'descricao': _descricaoController.text.trim(),
          'tipoDenuncia':
              _tipoDenunciaSelecionado, // Salvando o tipo de denúncia
          'data': FieldValue.serverTimestamp(),
          'status': 'Pendente',
          'imagemUrl': imagemUrl,
          'localizacao':
              _localizacao != null
                  ? {
                    'latitude': _localizacao!.latitude,
                    'longitude': _localizacao!.longitude,
                  }
                  : null,
          'userId': user.uid, // Salvando o ID do usuário
        });

        if (!mounted) return; // Verificação adicional de mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denúncia enviada com sucesso!')),
        );
        Navigator.pop(context); // Volta para a tela anterior após o envio
      } catch (e) {
        if (!mounted) return; // Verificação adicional de mounted
        print(
          'Erro ao enviar denúncia para Firebase: $e',
        ); // Log detalhado do erro
        String errorMessage = 'Erro ao enviar denúncia.';

        if (e is FirebaseException) {
          if (e.code == 'permission-denied') {
            errorMessage =
                'Permissão negada ao Firestore/Storage. Verifique as regras de segurança do Firebase.';
          } else if (e.code == 'storage/object-not-found') {
            errorMessage =
                'Erro ao fazer upload da imagem. O arquivo pode estar corrompido ou inacessível.';
          } else {
            errorMessage =
                'Erro do Firebase: ${e.message}'; // Mensagem genérica para outros erros do Firebase
          }
        } else if (e is Exception) {
          errorMessage =
              'Ocorreu um erro inesperado: ${e.toString()}'; // Mensagem para outros tipos de exceção
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Denúncia'),
        backgroundColor: const Color.fromARGB(255, 240, 71, 4),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite um título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Dropdown para Tipo de Denúncia
              DropdownButtonFormField<String>(
                value: _tipoDenunciaSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Sobre (Tipo de Denúncia)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                hint: const Text('Selecione o tipo de denúncia'),
                items:
                    _tiposDenuncia.map((String tipo) {
                      return DropdownMenuItem<String>(
                        value: tipo,
                        child: Text(tipo),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _tipoDenunciaSelecionado = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecione o tipo de denúncia';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite uma descrição';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed: _tirarFoto,
                    icon: const Icon(Icons.camera_alt),
                  ),
                  const Text('Tirar foto'),
                ],
              ),
              if (_imagem != null)
                Image.file(_imagem!, height: 150, fit: BoxFit.cover),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pegarLocalizacao,
                icon: const Icon(Icons.location_on),
                label: const Text('Usar minha localização'),
              ),
              if (_localizacao != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Localização: (${_localizacao!.latitude.toStringAsFixed(5)}, ${_localizacao!.longitude.toStringAsFixed(5)})',
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
