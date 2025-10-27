// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart'; // Importer le thème pour les couleurs

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pin1Controller = TextEditingController();
  final TextEditingController _pin2Controller = TextEditingController();
  final TextEditingController _pin3Controller = TextEditingController();
  final TextEditingController _pin4Controller = TextEditingController();

  final FocusNode _phoneFocus = FocusNode();
  final List<FocusNode> _pinFocusNodes = List.generate(4, (index) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  bool _rememberMe = false; // Checkbox state

  @override
  void dispose() {
    _phoneController.dispose();
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    _pin3Controller.dispose();
    _pin4Controller.dispose();
    _phoneFocus.dispose();
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getPin() {
    return _pin1Controller.text + _pin2Controller.text + _pin3Controller.text + _pin4Controller.text;
  }
  
  void _pinInputHandler(String value, int index) {
    if (value.length == 1) {
      if (index < 3) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        _pinFocusNodes[index].unfocus(); 
      }
    } else if (value.isEmpty && index > 0) {
      _pinFocusNodes[index - 1].requestFocus();
    }
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }


  void _login() async {
    final pin = _getPin();

    if (pin.length != 4) {
      setState(() {
        _errorMessage = 'Veuillez entrer un code PIN à 4 chiffres.';
      });
      if (_pin1Controller.text.isEmpty) _pinFocusNodes[0].requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // **CORRECTION : Ajout de l'argument rememberMe**
      await Provider.of<AuthService>(context, listen: false).login(
        _phoneController.text.trim(),
        pin,
        rememberMe: _rememberMe, // <-- Argument ajouté ici
      );

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      // Vérifier si le widget est toujours monté avant d'appeler setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildPinInput(TextEditingController controller, FocusNode focusNode, int index) {
      return SizedBox(
        width: 60,
        height: 60,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          obscureText: true,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600), // <-- Ajout const
          decoration: InputDecoration(
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2.0), // <-- Ajout const
            ),
          ),
          onChanged: (value) => _pinInputHandler(value, index),
        ),
      );
    }
    
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 50), // <-- Ajout const
              const Text( // <-- Ajout const
                'WINK EXPRESS',
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: AppTheme.secondaryColor 
                ),
              ),
              const SizedBox(height: 30), // <-- Ajout const
              Text(
                'Connexion à votre compte',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30), // <-- Ajout const
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Numéro de téléphone', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.secondaryColor)), // <-- Ajout const
                  const SizedBox(height: 8), // <-- Ajout const
                  TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration( // <-- Ajout const
                      hintText: '650724683',
                      prefixIcon: Icon(Icons.phone),
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    onSubmitted: (_) => _pinFocusNodes[0].requestFocus(),
                  ),
                  const Padding( // <-- Ajout const
                    padding: EdgeInsets.only(top: 5.0, left: 16.0),
                    child: Text('Ex: 650724683', style: TextStyle(fontSize: 12, color: AppTheme.secondaryColor)),
                  ),
                ],
              ),
              const SizedBox(height: 25), // <-- Ajout const

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Code PIN', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.secondaryColor)), // <-- Ajout const
                  const SizedBox(height: 8), // <-- Ajout const
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      buildPinInput(_pin1Controller, _pinFocusNodes[0], 0),
                      buildPinInput(_pin2Controller, _pinFocusNodes[1], 1),
                      buildPinInput(_pin3Controller, _pinFocusNodes[2], 2),
                      buildPinInput(_pin4Controller, _pinFocusNodes[3], 3),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20), // <-- Ajout const
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (bool? newValue) {
                          setState(() {
                            _rememberMe = newValue ?? false;
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                      const Text('Se souvenir de moi', style: TextStyle(color: AppTheme.secondaryColor)), // <-- Ajout const
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      // TODO: Implémenter la navigation vers l'écran "Code PIN oublié ?"
                      debugPrint("Code PIN oublié ? Click");
                    },
                    child: const Text( // <-- Ajout const
                      'Code PIN oublié ?',
                      style: TextStyle(
                        color: AppTheme.accentColor, 
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25), // <-- Ajout const

              if (_errorMessage != null) 
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold), // <-- Ajout const
                    textAlign: TextAlign.center,
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15), // <-- Ajout const
                    backgroundColor: AppTheme.primaryColor, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox( // <-- Ajout const
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('SE CONNECTER', style: TextStyle(fontSize: 16)), // <-- Ajout const
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}