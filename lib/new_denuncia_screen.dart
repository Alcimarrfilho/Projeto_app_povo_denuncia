import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Importe o Google Maps

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
  Position? _localizacaoAtual; // Posição obtida inicialmente pelo GPS
  LatLng? _localizacaoSelecionadaNoMapa; // Posição final selecionada no mapa

  GoogleMapController? _mapController; // Controlador do mapa
  bool _mostrarMapa = false; // Controle de visibilidade do mapa
  Set<Marker> _marcadores = {}; // Conjunto de marcadores no mapa

  String?
  _tipoDenunciaSelecionado; // Variável de estado para o tipo de denúncia

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
    _mapController?.dispose(); // Descarte o controlador do mapa
    super.dispose();
  }

  // Função chamada quando o mapa é criado
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Se já tiver uma localização atual, move a câmera para ela e adiciona o marcador
    if (_localizacaoAtual != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_localizacaoAtual!.latitude, _localizacaoAtual!.longitude),
        ),
      );
      _adicionarMarcador(
        LatLng(_localizacaoAtual!.latitude, _localizacaoAtual!.longitude),
      );
    }
  }

  // Adiciona ou move o marcador no mapa
  void _adicionarMarcador(LatLng position) {
    setState(() {
      _marcadores.clear(); // Limpa marcadores anteriores
      _marcadores.add(
        Marker(
          markerId: const MarkerId('denunciaLocation'),
          position: position,
          draggable: true, // Permite arrastar o marcador
          onDragEnd: (newPosition) {
            // Atualiza a localização selecionada quando o marcador é arrastado
            setState(() {
              _localizacaoSelecionadaNoMapa = newPosition;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Localização do marcador atualizada!'),
                backgroundColor: Colors.blueAccent,
              ),
            );
          },
        ),
      );
      _localizacaoSelecionadaNoMapa =
          position; // Atualiza a localização selecionada
    });
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

  // Função para obter localização atual e exibir o mapa
  Future<void> _pegarLocalizacaoEExibirMapa() async {
    if (!mounted) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative a localização no dispositivo')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _localizacaoAtual = position; // Armazena a localização inicial do GPS
        _localizacaoSelecionadaNoMapa = LatLng(
          position.latitude,
          position.longitude,
        ); // Define a localização inicial no mapa
        _mostrarMapa = true; // Exibe o mapa!
      });
      // Se o mapa já estiver criado, move a câmera para a localização
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
      _adicionarMarcador(
        LatLng(position.latitude, position.longitude),
      ); // Adiciona marcador na localização inicial
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Localização obtida. Arraste o marcador para ajustar!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter localização: ${e.toString()}')),
      );
      print('Erro ao obter localização: $e');
    }
  }

  // Função para confirmar a localização selecionada no mapa
  void _confirmarLocalizacaoNoMapa() {
    if (_localizacaoSelecionadaNoMapa != null) {
      setState(() {
        _mostrarMapa = false; // Esconde o mapa após a confirmação
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Localização confirmada!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma localização selecionada no mapa.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _enviarDenuncia() async {
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
      // Validação para o tipo de denúncia
      if (_tipoDenunciaSelecionado == null ||
          _tipoDenunciaSelecionado!.isEmpty) {
        if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Você precisa estar logado para enviar uma denúncia.',
            ),
          ),
        );
        return;
      }

      // Validação final da localização: certifica-se de que uma localização foi selecionada no mapa
      if (_localizacaoSelecionadaNoMapa == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Por favor, obtenha e selecione a localização no mapa.',
            ),
          ),
        );
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

        // Salva a denúncia no Firestore, usando a localização selecionada no mapa
        await FirebaseFirestore.instance.collection('denuncias').add({
          'titulo': _tituloController.text.trim(),
          'descricao': _descricaoController.text.trim(),
          'tipoDenuncia': _tipoDenunciaSelecionado,
          'data': FieldValue.serverTimestamp(),
          'status': 'Pendente',
          'imagemUrl': imagemUrl,
          'localizacao': {
            // Usamos a localização Latitude/Longitude do mapa
            'latitude': _localizacaoSelecionadaNoMapa!.latitude,
            'longitude': _localizacaoSelecionadaNoMapa!.longitude,
          },
          'userId': user.uid, // Salva o ID do usuário que fez a denúncia
        });

        if (!mounted) return; // Verificação adicional de mounted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denúncia enviada com sucesso!')),
        );
        Navigator.pushReplacementNamed(
          context,
          '/feed',
        ); // Volta para a tela feed após o envio
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
              // Botão para obter localização e exibir o mapa
              ElevatedButton.icon(
                onPressed:
                    _pegarLocalizacaoEExibirMapa, // Função que agora exibe o mapa
                icon: const Icon(Icons.location_on),
                label: const Text(' Selecionar no mapa'), // Novo texto do botão
              ),
              const SizedBox(height: 16),
              // Exibe o mapa condicionalmente se _mostrarMapa for true
              if (_mostrarMapa) // A visibilidade do mapa é controlada por esta variável
                Column(
                  children: [
                    Container(
                      height: 300, // Altura fixa para o mapa
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GoogleMap(
                        // O widget GoogleMap é renderizado aqui
                        onMapCreated:
                            _onMapCreated, // Callback quando o mapa é inicializado
                        initialCameraPosition: CameraPosition(
                          target:
                              _localizacaoAtual != null
                                  ? LatLng(
                                    _localizacaoAtual!.latitude,
                                    _localizacaoAtual!.longitude,
                                  )
                                  : const LatLng(
                                    -2.5312,
                                    -44.2958,
                                  ), // Posição inicial (ex: São Luís, MA) se GPS não disponível
                          zoom: 15.0,
                        ),
                        markers: _marcadores, // Exibe o marcador arrastável
                        myLocationEnabled:
                            true, // Habilita o ponto azul da localização do usuário
                        myLocationButtonEnabled:
                            true, // Botão para centralizar na localização do usuário
                        onTap:
                            _adicionarMarcador, // Permite tocar no mapa para mover o marcador
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Exibe as coordenadas selecionadas no mapa
                    if (_localizacaoSelecionadaNoMapa != null)
                      Text(
                        'Localização Selecionada: (${_localizacaoSelecionadaNoMapa!.latitude.toStringAsFixed(5)}, ${_localizacaoSelecionadaNoMapa!.longitude.toStringAsFixed(5)})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 16),
                    // Botão para confirmar a localização selecionada no mapa
                    ElevatedButton(
                      onPressed: _confirmarLocalizacaoNoMapa,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirmar Localização no Mapa'),
                    ),
                  ],
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
