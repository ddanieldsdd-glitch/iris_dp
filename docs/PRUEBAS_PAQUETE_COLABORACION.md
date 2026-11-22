# Pruebas del paquete de colaboración

Rama `plan/colaboracion-fase0`, sin publicar. Lleva cuatro cosas:
- **Errores a la vista (FI.4).**
- **Colaboración fase 0:** lo que se edita en vivo va solo al canal de su proyecto, y al editar una planta se bloquea para los demás.
- **Papeles por proyecto:** migración 019.
- **Invitaciones con enlace o correo y plan por cuenta:** migración 020.

**La versión de prueba** es «IRIS prueba» (`iris_dp_errores/build/IRIS prueba.app`). Lleva una copia de tus datos de hoy y está **conectada a la nube de IRIS de verdad**: lo que cambies en proyectos sincronizados llega a la nube. Para tocar sin miedo, usa un proyecto de prueba.

Marca cada punto al probarlo. Si algo falla, anota qué hiciste justo antes.

## 0. Entrar

- [ ] IRIS prueba pide iniciar sesión (es otra app para el Mac). Entra con tu cuenta.
- [ ] Abre normal: están El Bosque de Aldrun y KEBAB KHALED con sus planos.
- [ ] Ajustes › Invitados: ves «Cuentas», la nueva sección «Invitaciones a IRIS» y «Mantenimiento».

## 1. Equipo del proyecto (019)

- [ ] **Ver el equipo:** en la pantalla de proyectos, menú de la tarjeta de un proyecto subido a la nube › Editar, el botón dice «Equipo del proyecto», no «Invitar director». Al abrirlo, carga el equipo, o dice «Aún no hay nadie más».
- [ ] **Invitar:** pon un correo inventado (por ejemplo `prueba1@ejemplo.com`), papel Gaffer y pulsa «Crear invitación».
  - Se abre «Invitación lista» con un código tipo `K7M2-QX9P-4C`.
  - Al volver, sale en la lista como «Invitación pendiente · Gaffer».
- [ ] **Cambiar el papel** de esa invitación a «1.º ayudante de dirección»: se queda cambiado al cerrar y volver a abrir.
- [ ] **Retirarla** con la ✕ y confirmar: desaparece.
- [ ] **Invitar sin correo** (con el campo vacío): sale como «Enlace · Gaffer · 0/1 usos», con botones para compartir otra vez y retirar.

## 2. Compartir la invitación

- [ ] En «Invitación lista», **Compartir…** abre el menú del Mac (Mail, Mensajes…). El texto dice quién invita, a qué proyecto, con qué papel, el enlace y el código.
- [ ] **Correo** abre Mail con el destinatario puesto (si la invitación tenía correo), el asunto y el texto.
- [ ] **Copiar** avisa «Invitación copiada». Pégalo en Notas y comprueba que está todo.
- [ ] El enlace aún **no abre nada**: la página se publica al subir el paquete a main. Es lo esperado.

## 3. Invitar a alguien nuevo: la prueba importante

Hace falta un segundo correo tuyo (otra cuenta de Gmail, o el de un amigo que esté contigo).

**A. Con código**
- [ ] En Ajustes › Invitados › «Crear enlace», deja el correo vacío, elige «1 persona», pon la nota «prueba» y pulsa Crear. Copia el código.
- [ ] Cierra sesión en IRIS prueba y crea una cuenta nueva con el segundo correo (confírmala si llega correo de Supabase).
- [ ] Sale «Tu cuenta está pendiente» con el campo **Código de invitación**.
  - Un código mal escrito dice por qué no vale.
  - El bueno, escrito en minúsculas, con o sin guiones, entra en IRIS sin que tengas que aprobar nada.
- [ ] Pegar el enlace entero en vez del código también funciona. Pruébalo con otro enlace, porque cada uno vale una vez.
- [ ] Vuelve a tu cuenta. En Ajustes › Invitados, la invitación sale «1/1 usos · usada», y la cuenta nueva aparece en «Cuentas» como activa.

**B. Con correo y a un proyecto**
- [ ] Con tu cuenta: en «Equipo del proyecto» de un proyecto de prueba, invita al **tercer** correo (u otro alias) como Gaffer.
- [ ] Cierra sesión y crea la cuenta con ese correo: **entra directamente, sin pedir código**.
- [ ] Tras sincronizar, esa cuenta ve el proyecto. De vuelta en tu cuenta, el «Equipo del proyecto» la muestra como Gaffer.
- [ ] Quítala del proyecto (✕): deja de recibir sus cambios en la siguiente sincronización.

**C. Lo que no debe dejar**
- [ ] Un código ya usado dice «Esta invitación ya se ha usado».
- [ ] Un enlace retirado desde Ajustes › Invitados dice «Quien te invitó retiró esta invitación».
- [ ] Una invitación con correo, usada desde otra cuenta, dice «Esta invitación es para otro correo».

Al terminar, vuelve a entrar con tu cuenta. Si quieres, cierra el acceso de las cuentas de prueba en Ajustes › Invitados › Cuentas.

## 4. Colaboración en vivo (fase 0)

Necesita dos aparatos con esta versión, así que se prueba bien **después de publicar** (Mac + iPad). Con la versión de prueba solo:

- [ ] Abrir la planta de un plano y moverla **no** muestra avisos de bloqueo a ti mismo.
- [ ] Pasar de un plano a otro no deja el anterior bloqueado: el aviso «… está editando» desaparece al momento.

Tras publicar, en Mac + iPad con la misma cuenta:
- [ ] Mueve algo en la planta del plano 1 en el Mac. El iPad, en ese plano, dice «Daniel (propietario) · Mac está editando» y no deja editar. A los 2 minutos sin tocar se libera solo.
- [ ] En otro proyecto, el iPad no recibe avisos de lo que haces en el primero.

## 5. Errores (FI.4)

- [ ] Ajustes › «Compartir registro de errores»: tras un rato de uso normal, no hay errores nuevos sin explicar. Los que haya dicen dónde pasaron (sincronización, invitaciones…).
- [ ] Sin conexión (wifi apagada), abrir y usar la app no llena el registro de errores de red.

## Antes de publicar

- [ ] Cierra IRIS prueba. No la dejes abierta mientras se actualiza la app de verdad.
- [ ] Tu IRIS del Mac está en **1.13.0**: no se ha actualizado a 1.15.0 porque no se ha abierto desde el 19-11. Al publicar este paquete, ábrela para que se actualice.
