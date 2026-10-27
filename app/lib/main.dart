import 'package:flutter/material.dart';
import 'screens/admin_screen.dart';
import 'screens/aluno_screen.dart';
import 'screens/login_screen.dart';
import 'services/locker_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LockerService().restaurar();
  runApp(const SmartLockerApp());
}

class SmartLockerApp extends StatelessWidget {
  const SmartLockerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Smart Locker IFSP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF006400), useMaterial3: true),
        home: ValueListenableBuilder<Perfil?>(
          valueListenable: LockerService().sessao,
          builder: (_, p, __) {
            if (p == null) return const LoginScreen();
            return p.role == 'admin' ? const AdminScreen() : AlunoScreen(perfil: p);
          },
        ),
      );
}
