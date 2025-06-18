import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:developer'; // Importado para usar 'log'

class MinhasDenuncias extends StatefulWidget {
  const MinhasDenuncias({super.key});

  @override
  State<MinhasDenuncias> createState() => _MinhasDenunciasState();
}

class _MinhasDenunciasState extends State<MinhasDenuncias> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();

  DocumentSnapshot? _denunciaOriginal;
  File? _imagemNova;
  String? _imagemUrlExistente;

  LatLng? _localizacaoSelecionadaNoMapa;
  GoogleMapController? _mapController;
  bool _mostrarMapa = false;
  final Set<Marker> _marcadores = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarDadosDenuncia();
    });
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _carregarDadosDenuncia() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is DocumentSnapshot) {
      _denunciaOriginal = args;
      final data = _denunciaOriginal!.data() as Map<String, dynamic>;

      _descricaoController.text = data['descricao'] ?? '';
      _imagemUrlExistente = data['imagemUrl'];

      if (data['localizacao'] != null &&
          data['localizacao']['latitude'] != null &&
          data['localizacao']['longitude'] != null) {
        _localizacaoSelecionadaNoMapa = LatLng(
          data['localizacao']['latitude'],
          data['localizacao']['longitude'],
        );
        _adicionarMarcador(_localizacaoSelecionadaNoMapa!);
      }
      setState(() {});
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_localizacaoSelecionadaNoMapa != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(_localizacaoSelecionadaNoMapa!),
      );
    }
  }

  void _adicionarMarcador(LatLng position) {
    setState(() {
      _marcadores.clear();
      _marcadores.add(
        Marker(
          markerId: const MarkerId('denunciaLocation'),
          position: position,
          draggable: true,
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
      _localizacaoSelecionadaNoMapa = position;
    });
  }

  Future<void> _pegarLocalizacaoAtualEExibirMapa() async {
    if (!mounted) {
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative a localização no dispositivo')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) {
        return;
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _localizacaoSelecionadaNoMapa = LatLng(
          position.latitude,
          position.longitude,
        );
        _mostrarMapa = true;
      });
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_localizacaoSelecionadaNoMapa!),
        );
      }
      _adicionarMarcador(_localizacaoSelecionadaNoMapa!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Localização obtida. Arraste o marcador para ajustar!'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter localização: ${e.toString()}')),
      );
      log('Erro ao obter localização: $e'); // Usando log
    }
  }

  void _confirmarLocalizacaoNoMapa() {
    if (_localizacaoSelecionadaNoMapa != null) {
      setState(() {
        _mostrarMapa = false;
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

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: ImageSource.camera);

    if (foto != null) {
      setState(() {
        _imagemNova = File(foto.path);
        _imagemUrlExistente = null;
      });
    }
  }

  void _removerImagem() {
    setState(() {
      _imagemNova = null;
      _imagemUrlExistente = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Imagem removida!')));
  }

  Future<void> _salvarEdicao() async {
    if (!mounted) {
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_localizacaoSelecionadaNoMapa == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione a localização no mapa.'),
          ),
        );
        return;
      }

      try {
        String? newImageUrl = _imagemUrlExistente;

        if (_imagemNova != null) {
          final ref = FirebaseStorage.instance.ref(
            'denuncias/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await ref.putFile(_imagemNova!);
          newImageUrl = await ref.getDownloadURL();

          if (_imagemUrlExistente != null && _imagemUrlExistente!.isNotEmpty) {
            try {
              await FirebaseStorage.instance
                  .refFromURL(_imagemUrlExistente!)
                  .delete();
            } catch (e) {
              log('Erro ao excluir imagem antiga do Storage: $e'); // Usando log
            }
          }
        } else if (_imagemUrlExistente == null &&
            _denunciaOriginal != null &&
            _denunciaOriginal!['imagemUrl'] != null &&
            (_denunciaOriginal!['imagemUrl'] as String).isNotEmpty) {
          newImageUrl = null;
          try {
            await FirebaseStorage.instance
                .refFromURL(_denunciaOriginal!['imagemUrl'])
                .delete();
          } catch (e) {
            log(
              'Erro ao excluir imagem do Storage após remoção no formulário: $e',
            );
          }
        }

        await FirebaseFirestore.instance
            .collection('denuncias')
            .doc(_denunciaOriginal!.id)
            .update({
              'descricao': _descricaoController.text.trim(),
              'imagemUrl': newImageUrl,
              'localizacao': {
                'latitude': _localizacaoSelecionadaNoMapa!.latitude,
                'longitude': _localizacaoSelecionadaNoMapa!.longitude,
              },
              'dataAtualizacao': FieldValue.serverTimestamp(),
            });

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Denúncia atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) {
          return;
        }
        log('Erro ao atualizar denúncia no Firebase: $e'); // Usando log
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
              if (_mostrarMapa || _localizacaoSelecionadaNoMapa != null)
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
                              _localizacaoSelecionadaNoMapa ??
                              const LatLng(-2.5312, -44.2958),
                          zoom: 15.0,
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
                    onPressed: _salvarEdicao,
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
