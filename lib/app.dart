import 'package:flutter/material.dart';
import 'core/auth_wrapper.dart';

import 'modules/resources/resource_page.dart';
import 'modules/resources/resource_detail_page.dart';
import 'modules/admin/resource_admin_list.dart';
import 'modules/admin/resource_admin_edit.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IKUN app',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Raleway',
      ),
      home: AuthWrapper(),
      routes: {
        '/resources': (_) => const ResourcesPage(),
        '/resource-detail': (_) => const ResourceDetailPage(),
        '/admin/resources': (_) => const ResourceAdminListPage(),
        '/admin/resources/edit': (_) => const ResourceAdminEditPage(),
      },
    );
  }
}