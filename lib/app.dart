import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/cattle/data/cattle_repository.dart';
import 'features/cattle_transfer/data/cattle_transfer_repository.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/farms/data/farms_repository.dart';
import 'features/nedostatak_markica/data/nedostatak_markica_repository.dart';
import 'features/upload/data/upload_repository.dart';
import 'features/uparivanje_teladi/data/uparivanje_teladi_repository.dart';

class DalekoproApp extends StatefulWidget {
  const DalekoproApp({super.key});

  @override
  State<DalekoproApp> createState() => _DalekoproAppState();
}

class _DalekoproAppState extends State<DalekoproApp> {
  final TokenStorage _tokenStorage = const TokenStorage();
  String? _token;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.readToken();
    if (!mounted) return;
    setState(() {
      _token = token;
      _loading = false;
    });
  }

  void _onLogin(String token) {
    setState(() {
      _token = token;
    });
  }

  Future<void> _logout() async {
    await _tokenStorage.clearSession();
    if (!mounted) return;
    setState(() {
      _token = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final client = ApiClient(tokenStorage: _tokenStorage);
    final authRepository = AuthRepository(
      client: client,
      tokenStorage: _tokenStorage,
    );
    final farmsRepository = FarmsRepository(client: client);
    final cattleRepository = CattleRepository(client: client);
    final cattleTransferRepository = CattleTransferRepository(client: client);
    final uploadRepository = UploadRepository(client: client);
    final uparivanjeTeladiRepository = UparivanjeTeladiRepository(client: client);
    final nedostatakMarkicaRepository =
        NedostatakMarkicaRepository(client: client);

    return MaterialApp(
      title: 'Dalekopro Farma',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (_token == null
                ? LoginScreen(repository: authRepository, onLogin: _onLogin)
                : DashboardScreen(
                    farmsRepository: farmsRepository,
                    cattleRepository: cattleRepository,
                    cattleTransferRepository: cattleTransferRepository,
                    uploadRepository: uploadRepository,
                    uparivanjeTeladiRepository: uparivanjeTeladiRepository,
                    nedostatakMarkicaRepository: nedostatakMarkicaRepository,
                    onLogout: _logout,
                  )),
    );
  }
}
