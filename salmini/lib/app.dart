import 'package:flutter/material.dart';
import 'package:salmini/features/map/map_display.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routes.dart';

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
        '/': (context) => MapDisplayScreen(),
      },
      onGenerateRoute: (settings) {
        return generateRoute(settings);
      },
    );
  }
}