# MyPocket

Aplicación Flutter en español para llevar el registro personal de pedidos,
turnos, dinero generado, gastos, deudas y recordatorios de trabajo.
Identificador móvil de pruebas: `com.mypocket.app`.

## Funcionalidades

- Primer inicio con opción de usar la app como invitado o iniciar sesión con
  Google; permite guardar un nombre para personalizar el espacio financiero.
- Registro, edición y eliminación de pedidos.
- Pantallas independientes para resumen, pedidos, turnos, finanzas, deudas y calendario.
- Registro manual de pedidos de uno en uno desde la pantalla Pedidos.
- Cálculo por pedido: $1.300 base, más $75 por producto de lunes a sábado o
  $90 los domingos. La tarifa se calcula desde la fecha del pedido y no se
  guarda como un valor independiente.
- Bonos seleccionables por pedido entre $100 y $1.000, y por turno entre
  $1.000 y $12.000.
- Registro de turnos, horarios de entrada y salida, y bonos por turno.
- Historial de turnos con el total de pedidos vinculados a cada fecha más el
  bono del turno.
- Resumen mensual con dinero bruto generado y una estimación neta después de
  aplicar el porcentaje de retención configurable en Ajustes (15,25% inicial).
- Los pedidos y bonos se agrupan en boletas con fechas configurables (6 y 21
  inicialmente). Solo al marcar una boleta como recibida se agrega su neto
  estimado al dinero actual.
- El saldo actual suma las boletas recibidas y otros ingresos, y resta gastos
  pagados con débito, pagos de deuda y cobros de tarjeta facturados. El dinero
  generado aún no recibido no aumenta el saldo.
- Registro de otros ingresos recibidos, como el sueldo de otro trabajo.
- Registro, edición y eliminación de gastos puntuales con categoría, nota y
  método de pago: débito descuenta el saldo al instante y crédito queda para la
  siguiente facturación.
- Deudas separadas entre tarjeta de crédito (cuotas) y pagos del mes
  (compromisos recurrentes). Cada vencimiento tiene una fecha editable por mes
  y solo se descuenta del saldo al registrar el pago.
- La acción «Facturación realizada» marca los gastos de crédito del ciclo y
  las cuotas correspondientes como pagados, descontándolos del dinero actual.
  El día de facturación inicial es el 5 y se puede cambiar en Ajustes.
- Historial de pedidos, turnos y gastos consultable por mes o en todo el año.
- Calendario navegable por mes y año con turnos, pedidos, gastos, vencimientos
  de deudas, notas y eventos con hora de inicio, descripción y notificación
  local configurable: al inicio, 10 o 30 minutos, 1 hora o 1 día antes.
- Widget «Agenda MyPocket» para la pantalla de inicio del teléfono, con los
  eventos de hoy y los próximos eventos. En Android se agrega desde el selector
  de widgets del teléfono; en iPhone/iPad se agrega manteniendo pulsada la
  pantalla de inicio y usando «Añadir widget». El widget requiere abrir la app
  al menos una vez para compartir la agenda.
- Los avisos de eventos requieren permiso de notificaciones. Android puede
  entregarlos con algunos minutos de variación según las restricciones de ahorro
  de batería del dispositivo.
- Historial guardado localmente con SQLite y sincronizado entre dispositivos
  cuando se inicia sesión con la misma cuenta de Google. Los cambios se
  sincronizan al guardar y se reciben mientras MyPocket está abierta. Hace falta
  conexión a internet; si no hay conexión, los cambios siguen guardándose en el
  dispositivo y se reintentan al volver a abrir la app o guardar otro registro.
- La sincronización incluye pedidos, turnos, gastos, deudas y pagos, otros
  ingresos, boletas, fechas de ciclo, apariencia, retención, notas y eventos del
  calendario. El nombre elegido para la pantalla de inicio permanece local en
  cada dispositivo.
- La nube usa Firebase Authentication y Cloud Firestore, con reglas que limitan
  cada cuenta a sus propios datos. Firebase ofrece cuotas gratuitas con límites
  de uso; el proyecto se mantiene en el plan gratuito mientras no se cambie.
- Los eventos y sus descripciones se sincronizan entre los dispositivos
  vinculados. Evita guardar nombres u otros datos clínicos identificables de
  pacientes y comparte esa información solo cuando tengas autorización.
- Cada instalación se vincula a una sola cuenta de Google para impedir que los
  datos locales se mezclen accidentalmente con otra cuenta. Cerrar sesión no
  elimina los datos locales.
- Preferencias locales para activar el modo oscuro y elegir el color principal
  entre verde, rosa y azul.
- Al actualizar desde la versión anterior, los pagos salientes se conservan
  como deudas de una cuota con su estado y fecha; los ciclos de pedidos ya
  vencidos se migran como boletas recibidas para conservar el saldo histórico.
- La actualización a la versión 5 migra los pedidos existentes y elimina de la
  base local la tarifa SKU duplicada para calcularla siempre desde la fecha.
- La versión 6 conserva los ajustes existentes, agrega el porcentaje de
  retención configurable y crea la tabla de eventos sin alterar notas anteriores.
- La versión 7 agrega los metadatos locales necesarios para sincronizar registros
  entre dispositivos y conservar cambios y eliminaciones.
- La versión 8 agrega el método de pago de gastos, vencimientos mensuales y
  ciclos de boleta/facturación; la versión 9 conserva el ciclo exacto al
  registrar, editar o eliminar gastos de tarjeta ya facturados.
- La versión 10 agrega la anticipación del aviso en los eventos existentes, con
  aviso al inicio como valor predeterminado.
- La retención del SII es una estimación de referencia para boletas de
  honorarios, no el cálculo del impuesto anual ni asesoría tributaria. Fuente:
  [SII: retención de boletas de honorarios 2026](https://www.sii.cl/destacados/boletas_honorarios/).

## Desarrollo

Requisitos: Flutter SDK y Android SDK configurados.

```shell
flutter pub get
flutter test
flutter run
flutter build apk --release
```

El APK se genera en `build/app/outputs/flutter-apk/app-release.apk`. El APK de
distribución directa queda firmado con la clave debug de Android; para publicarlo
en Google Play se debe configurar una clave de firma de producción propia. El
identificador de paquete se cambió durante esta etapa de pruebas, así que una
instalación con el nuevo identificador no hereda los datos locales de la app
anterior.

La app también incluye el proyecto de iOS y una extensión WidgetKit, pero
compilar, firmar o publicar para iOS requiere macOS con Xcode y la configuración
de App Groups para el equipo de Apple correspondiente.
