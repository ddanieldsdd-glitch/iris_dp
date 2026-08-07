import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_providers.dart';
import '../../core/cloud/cloud_session.dart';
import '../../core/cloud/supabase_health_check.dart';
import '../../core/sync/project_sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/auth/cloud_connection_widgets.dart';

enum AuthMode { signIn, signUp }

/// Login / registro para modo nube — UI guiada para el tutorial.
class AuthScreen extends ConsumerStatefulWidget {
  final VoidCallback onAuthenticated;

  /// Si true, muestra instrucciones del tutorial y estado Supabase.
  final bool embeddedInTutorial;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
    this.embeddedInTutorial = false,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  var _mode = AuthMode.signIn;
  var _isDirector = false;
  var _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String _friendlyAuthError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos. Si es tu primera vez, pulsa «Crear cuenta».';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirma tu email en Supabase o desactiva «Confirm email» en Authentication → Providers.';
    }
    if (msg.contains('user already registered')) {
      return 'Ese email ya existe. Cambia a «Ya tengo cuenta» e inicia sesión.';
    }
    if (msg.contains('password')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (msg.contains('failed host lookup') ||
        msg.contains('nxdomain') ||
        msg.contains('nodename nor servname')) {
      return 'No se encuentra tu servidor Supabase. La URL del proyecto es '
          'incorrecta o el proyecto no existe.\n\n'
          'Abre supabase.com → Settings → API y copia la «Project URL» correcta. '
          'Luego recompila la app con --dart-define=SUPABASE_URL=...';
    }
    if (msg.contains('socketexception') || msg.contains('clientexception')) {
      return 'Sin conexión a Supabase. Comprueba internet o que la URL del '
          'proyecto sea la correcta en supabase.com.';
    }
    if (msg.contains('workspace_members') ||
        msg.contains('pgrst205') ||
        msg.contains('schema cache')) {
      return 'Falta configurar la base de datos en Supabase.\n\n'
          '1. Abre supabase.com → SQL Editor\n'
          '2. Pega y ejecuta supabase/migrations/001_initial_schema.sql\n'
          '3. Crea el bucket Storage «project-media»\n'
          '4. Vuelve a iniciar sesión aquí';
    }
    if (msg.contains('infinite recursion') || msg.contains('42p17')) {
      return 'Error de permisos en Supabase (RLS).\n\n'
          'Ejecuta en SQL Editor el archivo:\n'
          'supabase/migrations/003_fix_rls_recursion.sql\n\n'
          'Luego vuelve a iniciar sesión.';
    }
    if (msg.contains('workspaces_owner_id_fkey') ||
        msg.contains('not present in table "profiles"') ||
        msg.contains('23503')) {
      return 'Tu usuario existe en Auth pero falta el perfil en la base de datos.\n\n'
          'Ejecuta en SQL Editor:\n'
          'supabase/migrations/004_backfill_profiles.sql\n\n'
          'Luego vuelve a iniciar sesión.';
    }
    return e.toString();
  }

  Future<bool> _ensureReachable() async {
    final health = await checkSupabaseReachability();
    if (health.ok) return true;
    if (health.reachable) return true;
    if (mounted) {
      AppSnackBar.showError(
        context,
        '${health.message}\n\nSi tu navegador abre la URL de Supabase, '
        'puedes ignorar este aviso e intentar entrar.',
      );
    }
    // No bloquear login: el navegador del usuario puede resolver DNS aunque
    // el primer probe falle en macOS sandbox.
    return true;
  }

  Future<void> _submit() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Supabase no está configurado. Arranca la app con SUPABASE_URL y SUPABASE_ANON_KEY.',
        );
      }
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      AppSnackBar.showError(context, 'Introduce email y contraseña.');
      return;
    }

    if (!await _ensureReachable()) return;

    setState(() => _loading = true);
    try {
      if (_mode == AuthMode.signUp) {
        final response = await client.auth.signUp(
          email: email,
          password: password,
          data: {
            'display_name': _nameCtrl.text.trim(),
            'role': _isDirector ? 'director' : 'dp',
          },
        );
        if (!mounted) return;

        if (response.session == null && response.user != null) {
          AppSnackBar.show(
            context,
            'Cuenta creada. Revisa tu email para confirmar, o desactiva '
            '«Confirm email» en Supabase para entrar al instante.',
          );
          return;
        }
        AppSnackBar.show(context, 'Cuenta creada correctamente.');
      } else {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      if (client.auth.currentUser != null) {
        await _setupWorkspace(client);
        if (mounted) widget.onAuthenticated();
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setupWorkspace(dynamic client) async {
    final user = client.auth.currentUser!;
    final meta = user.userMetadata ?? {};
    final role = meta['role'] as String? ?? 'dp';
    final displayName = meta['display_name'] as String? ??
        user.email?.split('@').first ??
        'Usuario';

    if (role == 'director') {
      final inviteService = ProjectInviteService(client);
      await inviteService.acceptPendingInvitations();
      await CloudSessionStore.saveWorkspace(
        id: 'director',
        name: displayName,
        role: CloudUserRole.director,
      );
    } else {
      final ws = WorkspaceService(client);
      final workspace = await ws.ensureOwnerWorkspace(displayName: displayName);
      await CloudSessionStore.saveWorkspace(
        id: workspace.id,
        name: workspace.name,
        role: CloudUserRole.dpOwner,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isSignUp = _mode == AuthMode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.embeddedInTutorial) ...[
                    const CloudConnectionStatusCard(),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paso actual: tu cuenta IRIS DP',
                            style: AppTypography.titleMedium(palette).copyWith(
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const TutorialNumberedSteps(
                            steps: [
                              'Elige «Crear cuenta» si es tu primera vez (director de fotografía).',
                              'Elige «Ya tengo cuenta» si ya te registraste antes.',
                              'Introduce email y contraseña, luego pulsa el botón grande de abajo.',
                              'Tras entrar, elegirás las carpetas locales y podrás sincronizar.',
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  Text('IRIS DP', style: AppTypography.displayMedium(palette)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isSignUp
                        ? 'Crea tu cuenta para guardar proyectos en la nube'
                        : 'Inicia sesión con tu email y contraseña',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedButton<AuthMode>(
                    segments: const [
                      ButtonSegment(
                        value: AuthMode.signUp,
                        label: Text('Crear cuenta'),
                        icon: Icon(Icons.person_add_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: AuthMode.signIn,
                        label: Text('Ya tengo cuenta'),
                        icon: Icon(Icons.login, size: 18),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (isSignUp) ...[
                    TextField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tu nombre',
                        hintText: 'Ej. Daniel',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Soy director invitado'),
                      subtitle: const Text(
                        'Solo si te invitaron a un proyecto. Si eres DP y es tu '
                        'primera cuenta, déjalo APAGADO.',
                      ),
                      value: _isDirector,
                      onChanged: (v) => setState(() => _isDirector = v),
                    ),
                    if (_isDirector)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          '⚠ Primera vez como director de fotografía: desactiva '
                          'esta opción.',
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.warning,
                          ),
                        ),
                      ),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'tu@email.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _loading ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _loading
                        ? 'Conectando…'
                        : (isSignUp ? 'Crear cuenta y continuar' : 'Iniciar sesión y continuar'),
                    icon: isSignUp ? Icons.person_add : Icons.login,
                    onTap: _loading ? null : _submit,
                  ),
                  if (!widget.embeddedInTutorial) ...[
                    const SizedBox(height: AppSpacing.md),
                    const CloudConnectionStatusCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla de login accesible desde proyectos cuando falta sesión.
class AuthScreenStandalone extends StatelessWidget {
  const AuthScreenStandalone({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      embeddedInTutorial: true,
      onAuthenticated: () => Navigator.of(context).pop(true),
    );
  }
}

Future<bool?> openAuthScreen(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const AuthScreenStandalone()),
  );
}
