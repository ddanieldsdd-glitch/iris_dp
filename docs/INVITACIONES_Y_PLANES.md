# Invitaciones y planes (2026-11-22)

Cómo entra alguien nuevo en IRIS hoy y qué está preparado para cuando se venda.

## Hoy: invitar gratis

| Quién invita | Desde dónde | Qué da |
|---|---|---|
| Administrador | Ajustes › Invitados › «Crear enlace» | Acceso a IRIS sin esperar aprobación, plan **probador**, gratis y sin fecha |
| Administrador | Ficha del proyecto › «Equipo del proyecto» | Lo de arriba y además el proyecto, con un papel |
| Dueño de un proyecto | Ficha del proyecto › «Equipo del proyecto» | Solo el proyecto. Si la persona aún no usa IRIS, el administrador aprueba su cuenta |

- **Con correo:** solo esa cuenta puede usarla, y se aplica sola cuando entra con ese correo, sin escribir código.
- **Sin correo:** vale para quien reciba el enlace, de 1 a 100 usos.
- Los enlaces caducan a los 30 días si nadie los usa. Se pueden retirar. Una cuenta cerrada por el administrador no se reabre con un enlace.
- IRIS no manda correos. «Compartir…» abre Correo, WhatsApp o Mensajes con el texto ya escrito.

El enlace lleva a `web_invite/invitacion/`, publicada en GitHub Pages. La página:
- saluda con quién invita y a qué;
- ofrece la descarga para el equipo que la abre: DMG en Mac, instalador en Windows;
- en iPhone y iPad, dice «próximamente» y ofrece mandarse el enlace;
- enseña el código y explica cómo pasar el aviso de Gatekeeper o SmartScreen.

Los datos van tras `#`, así que no llegan a ningún servidor.

**Servidor:** migración `supabase/migrations/020_invite_links.sql`, con las funciones `iris_create_invite`, `iris_redeem_invite` e `iris_revoke_invite`.

## Preparado para vender

- `app_access.plan` (`tester`, `trial`, `pro`, `team`) y `plan_expires_at`. Hoy todos son `tester` sin fecha.
- Si un plan ha caducado, la cuenta no puede escribir en la nube, la app muestra «Tu periodo de IRIS ha terminado» y deja escribir un código nuevo. Los proyectos del equipo no se tocan.
- Una invitación puede dar otro plan con días (`plan_days`): por ejemplo, una prueba de 30 días.
- `app_access.source` (`invite`, `manual`, `store`, `stripe`…) y `invited_by` dicen de dónde viene cada cuenta, para saber qué amigos traen gente o respetar a los primeros probadores.

### Lo que faltará

1. **Apple Developer Program (99 €/año).** Hace falta para:
   - TestFlight en iPhone y iPad para otros;
   - notarizar el DMG del Mac, para que no salga el aviso;
   - la App Store.
2. **Pago.** Cada canal escribe `plan` y `plan_expires_at` desde el servidor; la app no cambia:
   - **Stripe**, para Mac y Windows: una función de Supabase recibe el aviso de pago.
   - **App Store**, con StoreKit y las notificaciones del servidor de Apple.
3. **Dominio propio:** cambiar `kInvitePageUrl` en `lib/core/access/app_invite.dart` y el dominio de Pages. Los enlaces antiguos siguen yendo a GitHub Pages.
4. **Firma de Windows:** certificado de firma de código, para quitar el aviso de SmartScreen.
5. **Abrir IRIS desde el enlace** con `irisdp://`, sin copiar el código.
