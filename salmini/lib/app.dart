import 'package:flutter/material.dart';
import 'package:salmini/features/map/map_display.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routes.dart';
import 'package:salmini/features/auth/presentation/screens/register_screen.dart';
import 'package:salmini/features/auth/presentation/screens/login_screen.dart';
import 'package:salmini/features/auth/presentation/screens/welcome_screen.dart';
import 'package:salmini/features/dashboard/presentation/profile.dart';

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Salmini',
      theme: ThemeData(
        textTheme: GoogleFonts.slabo27pxTextTheme(),
        primarySwatch: Colors.green,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomeScreen(),
        '/register': (context) => RegisterScreen(),
        '/login': (context) => LoginScreen(),
        '/profile': (context) => ProfileScreen(),
      },
      onGenerateRoute: (settings) {
        return generateRoute(settings);
      },
    );
  }
}