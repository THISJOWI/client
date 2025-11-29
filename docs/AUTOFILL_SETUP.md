# Configuración del Servicio de Autofill de THISJOWI

Este documento explica cómo configurar THISJOWI como proveedor de contraseñas para otras aplicaciones.

## Android (Autofill Framework)

### Requisitos
- Android 8.0 (API 26) o superior
- La app debe estar instalada (no funciona en modo debug con hot reload)

### Archivos Creados
- `android/app/src/main/kotlin/.../ThisjowiAutofillService.kt` - Servicio de Autofill
- `android/app/src/main/kotlin/.../MainActivity.kt` - Comunicación con Flutter
- `android/app/src/main/res/xml/autofill_service_config.xml` - Configuración del servicio

### Cómo Funciona
1. El usuario activa THISJOWI como proveedor de autofill en Ajustes > Sistema > Idiomas y entrada > Servicio de autocompletar
2. Cuando otra app muestra campos de usuario/contraseña, Android detecta y muestra sugerencia de THISJOWI
3. Al tocar la sugerencia, se abre THISJOWI para autenticación
4. El usuario selecciona la contraseña y se autocompleta

### Probar en Android
```bash
# Compilar en release para probar autofill
flutter build apk --release
flutter install
```

Luego:
1. Ve a Ajustes > Sistema > Idiomas y entrada > Servicio de autocompletar
2. Selecciona "THISJOWI"
3. Abre cualquier app con login (ej: Twitter, Instagram)
4. Verás la opción de autocompletar con THISJOWI

---

## iOS (Credential Provider Extension)

### Requisitos
- iOS 12.0 o superior
- Cuenta de desarrollador de Apple (para App Groups)
- Xcode 14+

### Configuración en Xcode

#### 1. Crear el App Group

1. Abre `ios/Runner.xcworkspace` en Xcode
2. Selecciona el proyecto "Runner" en el navegador
3. Ve a "Signing & Capabilities"
4. Click en "+ Capability" y añade "App Groups"
5. Crea un nuevo grupo: `group.com.thisjowi.passwords`

#### 2. Añadir el Target de la Extensión

1. En Xcode: File > New > Target
2. Selecciona "AutoFill Credential Provider Extension"
3. Nombre: "AutofillExtension"
4. Asegúrate de que "Embed in Application" esté seleccionado para "Runner"

#### 3. Configurar la Extensión

1. Reemplaza el contenido de `AutofillExtension/CredentialProviderViewController.swift` con el archivo creado
2. Añade la capability "App Groups" al target de la extensión
3. Usa el mismo grupo: `group.com.thisjowi.passwords`

#### 4. Actualizar el Entitlements de Runner

Añade al archivo `Runner.entitlements`:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.thisjowi.passwords</string>
</array>
```

### Archivos Creados
- `ios/AutofillExtension/CredentialProviderViewController.swift` - UI de selección de contraseñas
- `ios/AutofillExtension/Info.plist` - Configuración de la extensión
- `ios/AutofillExtension/AutofillExtension.entitlements` - Permisos de la extensión
- `ios/Runner/AppDelegate.swift` - Actualizado con comunicación de credenciales

### Cómo Funciona
1. El usuario va a Ajustes > Contraseñas > Autorrellenar contraseñas
2. Activa "THISJOWI"
3. En Safari o cualquier app, al tocar un campo de contraseña aparece la sugerencia
4. El usuario selecciona THISJOWI y elige la contraseña

---

## Uso en Flutter

### Mostrar Estado de Autofill

```dart
import 'package:thisjowi/components/autofill_settings_card.dart';

// En tu pantalla de configuración:
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        const AutofillSettingsCard(),
        // ... otros widgets
      ],
    ),
  );
}
```

### Verificar y Activar Autofill

```dart
import 'package:thisjowi/services/autofill_service.dart';

final autofillService = AutofillService();

// Verificar soporte
final hasSupport = await autofillService.hasAutofillSupport();

// Verificar si está activado
final isEnabled = await autofillService.isAutofillServiceEnabled();

// Abrir configuración
await autofillService.openAutofillSettings();
```

### Sincronizar Contraseñas para iOS

```dart
import 'package:thisjowi/services/credential_sharing_service.dart';

final credentialService = CredentialSharingService();

// Después de crear/actualizar/eliminar contraseñas:
await credentialService.syncPasswordsToSharedStorage(passwords);
await credentialService.registerCredentialIdentities(passwords);
```

---

## Integración con Password Service

Actualiza tu `password_service.dart` para sincronizar automáticamente:

```dart
import 'credential_sharing_service.dart';

class PasswordService {
  final CredentialSharingService _credentialService = CredentialSharingService();

  Future<void> addPassword(Map<String, dynamic> data) async {
    // ... guardar contraseña ...
    
    // Sincronizar con iOS AutoFill
    final allPasswords = await fetchPasswords();
    await _credentialService.syncPasswordsToSharedStorage(allPasswords);
    await _credentialService.registerCredentialIdentities(allPasswords);
  }
}
```

---

## Solución de Problemas

### Android
- **No aparece la opción de autofill**: Asegúrate de compilar en release, no debug
- **Error de permisos**: Verifica que BIND_AUTOFILL_SERVICE esté en el manifest

### iOS
- **La extensión no aparece**: 
  1. Verifica que el target de extensión esté incluido en el scheme de build
  2. Reinicia el dispositivo después de instalar
- **Las contraseñas no se sincronizan**:
  1. Verifica que App Groups esté configurado en ambos targets
  2. Usa el mismo identificador de grupo

---

## Seguridad

⚠️ **Importante**: 
- Las contraseñas se almacenan encriptadas en la base de datos local
- Para iOS, las contraseñas se comparten a través de App Groups (almacenamiento seguro del sistema)
- Se recomienda requerir autenticación biométrica antes de proveer credenciales
