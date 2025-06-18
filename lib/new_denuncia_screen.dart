import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class NewDenunciaScreen extends StatefulWidget {
  const NewDenunciaScreen({super.key});

  @override
  State<NewDenunciaScreen> createState() => _NewDenunciaScreenState();
}

class _NewDenunciaScreenState extends State<NewDenunciaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _searchController = TextEditingController();

  File? _imagem;
  Position? _localizacaoAtual;
  LatLng? _localizacaoSelecionadaNoMapa;

  GoogleMapController? _mapController;
  bool _mostrarMapa = false;
  final Set<Marker> _marcadores = {};
  String? _tipoDenunciaSelecionado;
  final String googleApiKey = "AIzaSyA4G0pO8aV1J3c_YtI8p4C9FpiMOYkxtRA";

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
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Função chamada quando o mapa é criado
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
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
            setState(() {
              _localizacaoSelecionadaNoMapa = newPosition;
            });
            // SnackBar de "Localização do marcador atualizada!" removida anteriormente, mantida fora do escopo desta solicitação.
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
      // SnackBar de "Ative a localização no dispositivo"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ative a localização no seu dispositivo.'),
        ),
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
        // SnackBar de "Permissão de localização negada..."
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permissão de localização negada. Ative nas configurações do aplicativo.',
            ),
          ),
        );
        return;
      }
    }

    try {
      // Mantendo 'desiredAccuracy' conforme sua preferência.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _localizacaoAtual = position;
        _localizacaoSelecionadaNoMapa = LatLng(
          position.latitude,
          position.longitude,
        );
        _mostrarMapa = true; // Exibe o mapa
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
      _adicionarMarcador(
        LatLng(position.latitude, position.longitude),
      ); // Adiciona marcador na localização inicial
      // SnackBar de "Localização obtida..."
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Localização obtida com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      // SnackBar de "Erro ao obter localização..."
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter localização: ${e.toString()}')),
      );
    }
  }

  // FUNÇÃO para pesquisar um local e atualizar o mapa
  Future<void> _pesquisarLocalEAtualizarMapa(String query) async {
    if (!mounted || query.isEmpty) return;

    // Codifica a query para ser usada na URL
    final encodedQuery = Uri.encodeComponent(query);
    // Constrói a URL da API de Geocodificação do Google Maps
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedQuery&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url)); // Faz a requisição HTTP

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);

        // Verifica se a API retornou status 'OK' e encontrou resultados.
        if (decodedResponse['status'] == 'OK' &&
            decodedResponse['results'] != null &&
            decodedResponse['results'].isNotEmpty) {
          // Extrai a latitude e longitude do primeiro resultado.
          final geometry =
              decodedResponse['results'][0]['geometry']['location'];
          final newLatLng = LatLng(geometry['lat'], geometry['lng']);

          setState(() {
            _mostrarMapa = true; // Garante que o mapa esteja visível.
            _localizacaoSelecionadaNoMapa =
                newLatLng; // Atualiza a localização selecionada.
          });

          if (_mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(newLatLng));
          }
          _adicionarMarcador(newLatLng);
          // SnackBar de "Local encontrado!"
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Local encontrado!')));
        } else if (decodedResponse['status'] == 'ZERO_RESULTS') {
          // Tratamento para nenhum resultado.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            // SnackBar para ZERO_RESULTS
            const SnackBar(
              content: Text('Nenhum local encontrado para a pesquisa.'),
            ),
          );
        } else {
          // Tratamento para outros status de erro da API do Google.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            // SnackBar para outros erros da API
            SnackBar(
              content: Text(
                'Erro na API de Geocodificação: ${decodedResponse['status']}',
              ),
            ),
          );
        }
      } else {
        // Tratamento para erros de conexão HTTP (status code diferente de 200).
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          // SnackBar para erro de conexão HTTP
          SnackBar(
            content: Text('Erro de conexão com a API: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      // Captura erros gerais na requisição (ex: sem internet).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao pesquisar localização: ${e.toString()}'),
        ),
      );
    }
  }

  // Função para confirmar a localização selecionada no mapa
  void _confirmarLocalizacaoNoMapa() {
    if (_localizacaoSelecionadaNoMapa != null) {
      setState(() {
        _mostrarMapa = false; // Esconde o mapa após a confirmação
      });
      // SnackBar de "Localização confirmada!"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Localização confirmada!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma localização selecionada no mapa para confirmar.',
          ),
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

      // Ultima validação final da localização
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

        // Salva a denúncia no Firestore
        await FirebaseFirestore.instance.collection('denuncias').add({
          'titulo': _tituloController.text.trim(),
          'descricao': _descricaoController.text.trim(),
          'tipoDenuncia': _tipoDenunciaSelecionado,
          'data': FieldValue.serverTimestamp(),
          'status': 'Pendente',
          'imagemUrl': imagemUrl,
          'localizacao': {
            'latitude': _localizacaoSelecionadaNoMapa!.latitude,
            'longitude': _localizacaoSelecionadaNoMapa!.longitude,
          },
          'userId': user.uid, // Salva o ID do usuário que fez a denúncia
        });

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Denúncia enviada!')));
        Navigator.pushReplacementNamed(context, '/feed');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar denúncia: ${e.toString()}')),
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

              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Digite o endereço ou CEP',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                          : null,
                ),
                onChanged: (value) {
                  setState(() {});
                },
                onFieldSubmitted: (value) {
                  _pesquisarLocalEAtualizarMapa(value);
                },
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed:
                    () => _pesquisarLocalEAtualizarMapa(_searchController.text),
                icon: const Icon(Icons.my_location),
                label: const Text('Buscar no Mapa'),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _pegarLocalizacaoEExibirMapa,
                icon: const Icon(Icons.location_on),
                label: const Text('Usar Localização Atual'),
              ),
              const SizedBox(height: 16),

              if (_mostrarMapa)
                Column(
                  children: [
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                          target:
                              _localizacaoAtual != null
                                  ? LatLng(
                                    _localizacaoAtual!.latitude,
                                    _localizacaoAtual!.longitude,
                                  )
                                  : const LatLng(-5.0934, -42.8037),
                          zoom: 16.0,
                        ),
                        markers: _marcadores,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        onTap: _adicionarMarcador,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_localizacaoSelecionadaNoMapa != null)
                      Text(
                        'Localização Selecionada: (${_localizacaoSelecionadaNoMapa!.latitude.toStringAsFixed(5)}, ${_localizacaoSelecionadaNoMapa!.longitude.toStringAsFixed(5)})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 16),
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
