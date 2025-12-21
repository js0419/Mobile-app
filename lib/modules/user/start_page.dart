import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../user/login_page.dart';
import '../user/sign_up_page.dart';

class StartPage extends StatelessWidget{
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF93DA97),
                Color(0xFFE8FFD7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
        ),
        child: Padding(
            padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Text(
                'Start Your Healing Journey',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Small habits, better days.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: (){
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                            builder: (BuildContext context) => const SignUpPage()
                        )
                      );
                    },
                    child: const Text('SIGNUP')
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: (){
                      Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                              builder: (BuildContext context) => const LoginPage()
                          )
                      );
                    },
                    child: const Text('LOGIN')
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}