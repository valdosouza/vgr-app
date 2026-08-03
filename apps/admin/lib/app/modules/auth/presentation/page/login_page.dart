import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

import '../bloc/login_bloc.dart';
import '../bloc/login_event.dart';
import '../bloc/login_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VGR Admin — Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocConsumer<LoginBloc, LoginState>(
          listener: (context, state) {
            if (state is LoginSuccess) {
              Modular.to.navigate('/');
            }
          },
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('login-email-field'),
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  key: const Key('login-password-field'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 16),
                if (state is LoginError) Text(state.message),
                ElevatedButton(
                  key: const Key('login-submit-button'),
                  onPressed: state is LoginLoading
                      ? null
                      : () => context.read<LoginBloc>().add(LoginSubmitted(
                            email: _emailController.text,
                            password: _passwordController.text,
                          )),
                  child: state is LoginLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                      : const Text('Log in'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
