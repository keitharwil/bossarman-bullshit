import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../viewmodels/motohub_viewmodel.dart';
import 'admin/admin_shell_screen.dart';
import 'cashier/cashier_shell_screen.dart';
import 'login_screen.dart';
import 'shared/force_password_change_screen.dart';
import 'mechanic/mechanic_shell_screen.dart';

/// Internal ERP/POS Role Router (`main_internal.dart` — App A).
/// AUDIT FIX: Customer role is strictly decoupled into `main_customer.dart` (App B)
/// and is never routed inside the Internal Admin/Cashier/Mechanic app.
class RoleRouterScreen extends StatelessWidget {
  const RoleRouterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MotoHubViewModel>();
    final user = vm.currentUser;

    if (user == null || user.role == UserRole.customer) {
      return const LoginScreen();
    }

    if (vm.requiresPasswordChange) {
      return const ForcePasswordChangeScreen();
    }

    switch (user.role) {
      case UserRole.admin:
        return const AdminShellScreen();
      case UserRole.cashier:
        return const CashierShellScreen();
      case UserRole.mechanic:
        return const MechanicShellScreen();
      case UserRole.customer:
        return const LoginScreen();
    }
  }
}
