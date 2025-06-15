import 'dart:io'; // Para manipulação de arquivos de imagem
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Para upload e exclusão de imagens
import 'package:image_picker/image_picker.dart'; // Para selecionar/tirar fotos
import 'package:geolocator/geolocator.dart'; // Para obter localização GPS
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Para o mapa

class MinhasDenuncias extends StatefulWidget {
  const MinhasDenuncias({super.key});

  @override
  State<MinhasDenuncias> createState() => _MinhasDenunciasState();
}

class _MinhasDenunciasState extends State<MinhasDenuncias> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();

  DocumentSnapshot?
  _denunciaOriginal; // Armazena a denúncia original para edição
  String? _tipoDenunciaSelecionado;
  File? _imagemNova; // Nova imagem selecionada (substitui a antiga)
  String? _imagemUrlExistente; // URL da imagem já existente na denúncia

  LatLng? _localizacaoSelecionadaNoMapa; // Posição final selecionada no mapa
  GoogleMapController? _mapController; // Controlador do mapa
  bool _mostrarMapa = false; // Controle de visibilidade do mapa
  Set<Marker> _marcadores = {}; // Conjunto de marcadores no mapa

  final List<String> _tiposDenuncia = [
    'Abandono',
    'Buraco',
    'Poluição',
    'Estupro',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    // Preenche os controladores quando a denúncia original é carregada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosDenuncia();
    });
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Carrega os dados da denúncia passada como argumento
  void _carregarDadosDenuncia() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DocumentSnapshot) {
      _denunciaOriginal = args;
      final data = _denunciaOriginal!.data() as Map<String, dynamic>;

      _tituloController.text = data['titulo'] ?? '';
      _descricaoController.text = data['descricao'] ?? '';
      _tipoDenunciaSelecionado = data['tipoDenuncia'];
      _imagemUrlExistente = data['imagemUrl'];

      if (data['localizacao'] != null &&
          data['localizacao']['latitude'] != null &&
          data['localizacao']['longitude'] != null) {
        _localizacaoSelecionadaNoMapa = LatLng(
          data['localizacao']['latitude'],
          data['localizacao']['longitude'],
        );
        // Adiciona o marcador inicial se a localização já existir
        _adicionarMarcador(_localizacaoSelecionadaNoMapa!);
      }
      setState(() {}); // Atualiza a UI com os dados carregados
    }
  }

  // Função chamada quando o mapa é criado
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Se já tiver uma localização inicial, move a câmera para ela
    if (_localizacaoSelecionadaNoMapa != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_localizacaoSelecionadaNoMapa!),
      );
    }
  }

  // Adiciona ou move o marcador no mapa
  void _adicionarMarcador(LatLng position) {
    setState(() {
      _marcadores.clear();
      _marcadores.add(
        Marker(
          markerId: const MarkerId('denunciaLocation'),
          position: position,
          draggable: true, // Permite arrastar o marcador
          onDragEnd: (newPosition) {
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

  // Obtém a localização atual do GPS e exibe o mapa
  Future<void> _pegarLocalizacaoAtualEExibirMapa() async {
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
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _localizacaoSelecionadaNoMapa = LatLng(
          position.latitude,
          position.longitude,
        );
        _mostrarMapa = true; // Exibe o mapa
      });
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_localizacaoSelecionadaNoMapa!),
        );
      }
      _adicionarMarcador(
        _localizacaoSelecionadaNoMapa!,
      ); // Adiciona marcador na localização atual
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

  // Tira uma nova foto
  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.camera);

    if (foto != null) {
      setState(() {
        _imagemNova = File(foto.path);
        _imagemUrlExistente =
            null; // Remove a URL existente se uma nova foto for tirada
      });
    }
  }

  // Remove a imagem atual
  void _removerImagem() {
    setState(() {
      _imagemNova = null;
      _imagemUrlExistente = null; // Limpa a URL da imagem existente
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Imagem removida!')));
  }

  // Função para salvar as edições na denúncia
  Future<void> _salvarEdicao() async {
    if (!mounted) return;

    if (_formKey.currentState!.validate()) {
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

      if (_localizacaoSelecionadaNoMapa == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione a localização no mapa.'),
          ),
        );
        return;
      }

      try {
        String? newImageUrl =
            _imagemUrlExistente; // Mantém a URL existente por padrão

        // Se houver uma nova imagem, faz upload e atualiza a URL
        if (_imagemNova != null) {
          final ref = FirebaseStorage.instance.ref(
            'denuncias/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await ref.putFile(
            _imagemNova!,
          ); // CORRIGIDO AQUI: _imagem! para _imagemNova!
          newImageUrl = await ref.getDownloadURL();

          // Opcional: Se havia uma imagem existente e uma nova foi adicionada, exclua a antiga
          if (_imagemUrlExistente != null && _imagemUrlExistente!.isNotEmpty) {
            try {
              await FirebaseStorage.instance
                  .refFromURL(_imagemUrlExistente!)
                  .delete();
            } catch (e) {
              print('Erro ao excluir imagem antiga do Storage: $e');
            }
          }
        } else if (_imagemUrlExistente == null) {
          // Se não há nova imagem e a URL existente foi removida (botão "Remover Imagem")
          newImageUrl = null;
          // Opcional: Excluir a imagem do Storage se ela existia e foi removida na UI
          if (_denunciaOriginal != null &&
              _denunciaOriginal!['imagemUrl'] != null &&
              (_denunciaOriginal!['imagemUrl'] as String).isNotEmpty) {
            try {
              await FirebaseStorage.instance
                  .refFromURL(_denunciaOriginal!['imagemUrl'])
                  .delete();
            } catch (e) {
              print(
                'Erro ao excluir imagem do Storage após remoção no formulário: $e',
              );
            }
          }
        }

        // Atualiza a denúncia no Firestore
        await FirebaseFirestore.instance
            .collection('denuncias')
            .doc(_denunciaOriginal!.id)
            .update({
              'titulo': _tituloController.text.trim(),
              'descricao': _descricaoController.text.trim(),
              'tipoDenuncia': _tipoDenunciaSelecionado,
              'imagemUrl': newImageUrl, // Salva a nova URL ou null
              'localizacao': {
                'latitude': _localizacaoSelecionadaNoMapa!.latitude,
                'longitude': _localizacaoSelecionadaNoMapa!.longitude,
              },
              'dataAtualizacao':
                  FieldValue.serverTimestamp(), // Adiciona um timestamp de atualização
            });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Denúncia atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Volta para a tela anterior (feed)
      } catch (e) {
        if (!mounted) return;
        print('Erro ao atualizar denúncia no Firebase: $e');
        String errorMessage = 'Erro ao atualizar denúncia.';

        if (e is FirebaseException) {
          if (e.code == 'permission-denied') {
            errorMessage =
                'Permissão negada. Verifique as regras de segurança do Firebase.';
          } else {
            errorMessage = 'Erro do Firebase: ${e.message}';
          }
        } else {
          errorMessage = 'Ocorreu um erro inesperado: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_denunciaOriginal == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Editar Denúncia'),
          backgroundColor: const Color.fromARGB(255, 240, 71, 4),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Denúncia'),
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
              // Exibição e botões para Imagem
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _tirarFoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tirar Nova Foto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (_imagemNova != null || _imagemUrlExistente != null)
                    ElevatedButton.icon(
                      onPressed: _removerImagem,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Remover Imagem'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_imagemNova != null)
                Image.file(_imagemNova!, height: 150, fit: BoxFit.cover),
              if (_imagemNova == null && _imagemUrlExistente != null)
                Image.network(
                  _imagemUrlExistente!,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text(
                          'Erro ao carregar imagem',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              // Botão para obter localização e exibir/atualizar o mapa
              ElevatedButton.icon(
                onPressed: _pegarLocalizacaoAtualEExibirMapa,
                icon: const Icon(Icons.location_on),
                label: const Text('Obter Localização Atual e Usar no Mapa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Exibe o mapa condicionalmente
              if (_mostrarMapa || _localizacaoSelecionadaNoMapa != null)
                Column(
                  children: [
                    Container(
                      height: 300, // Altura fixa para o mapa
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        // Se já houver localização selecionada, usa-a como alvo inicial do mapa
                        initialCameraPosition: CameraPosition(
                          target:
                              _localizacaoSelecionadaNoMapa ??
                              const LatLng(
                                -2.5312,
                                -44.2958,
                              ), // Posição inicial (São Luís)
                          zoom: 15.0,
                        ),
                        markers: _marcadores,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
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
                    onPressed:
                        _salvarEdicao, // Chama a função para salvar as edições
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 240, 71, 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Salvar Edição',
                      style: TextStyle(fontSize: 16, color: Colors.white),
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
