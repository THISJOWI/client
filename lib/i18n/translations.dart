import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static final _t = Translations.byText("en") +
      // ==================== GENERAL ====================
      {
        "en": "Cancel",
        "es": "Cancelar",
      } +
      {
        "en": "Delete",
        "es": "Eliminar",
      } +
      {
        "en": "Save",
        "es": "Guardar",
      } +
      {
        "en": "Close",
        "es": "Cerrar",
      } +
      {
        "en": "Edit",
        "es": "Editar",
      } +
      {
        "en": "Create",
        "es": "Crear",
      } +
      {
        "en": "Search",
        "es": "Buscar",
      } +
      {
        "en": "Error",
        "es": "Error",
      } +
      {
        "en": "Success",
        "es": "Éxito",
      } +
      {
        "en": "Loading...",
        "es": "Cargando...",
      } +
      {
        "en": "Yes",
        "es": "Sí",
      } +
      {
        "en": "No",
        "es": "No",
      } +
      {
        "en": "Confirm",
        "es": "Confirmar",
      } +
      {
        "en": "or",
        "es": "o",
      } +
      {
        "en": "Use %s",
        "es": "Usar %s",
      } +

      // ==================== AUTH ====================
      {
        "en": "Welcome Back",
        "es": "Bienvenido de nuevo",
      } +
      {
        "en": "Sign in to continue",
        "es": "Inicia sesión para continuar",
      } +
      {
        "en": "Email",
        "es": "Correo electrónico",
      } +
      {
        "en": "Password",
        "es": "Contraseña",
      } +
      {
        "en": "Login",
        "es": "Iniciar sesión",
      } +
      {
        "en": "Register",
        "es": "Registrarse",
      } +
      {
        "en": "Logout",
        "es": "Cerrar sesión",
      } +
      {
        "en": "Create Account",
        "es": "Crear cuenta",
      } +
      {
        "en": "Sign up to get started",
        "es": "Regístrate para comenzar",
      } +
      {
        "en": "Please complete all fields",
        "es": "Por favor completa todos los campos",
      } +
      {
        "en": "Account created! Syncing in background...",
        "es": "¡Cuenta creada! Sincronizando en segundo plano...",
      } +
      {
        "en": "Register failed",
        "es": "Error en el registro",
      } +
      {
        "en": "Invalid credentials",
        "es": "Credenciales inválidas",
      } +
      {
        "en": "Logged in successfully",
        "es": "Sesión iniciada correctamente",
      } +
      {
        "en": "Logged in offline mode",
        "es": "Sesión iniciada en modo offline",
      } +
      {
        "en": "No internet connection. You need to login online at least once.",
        "es": "Sin conexión a internet. Necesitas iniciar sesión en línea al menos una vez.",
      } +
      {
        "en": "This user already exists locally. Please sign in.",
        "es": "Este usuario ya existe localmente. Por favor, inicia sesión.",
      } +
      {
        "en": "This user is already in the sync queue. Please wait for it to complete.",
        "es": "Este usuario ya está en la cola de sincronización. Por favor, espera a que se complete.",
      } +

      // ==================== PASSWORDS ====================
      {
        "en": "Passwords",
        "es": "Contraseñas",
      } +
      {
        "en": "Search passwords",
        "es": "Buscar contraseñas",
      } +
      {
        "en": "No passwords stored",
        "es": "No hay contraseñas guardadas",
      } +
      {
        "en": "Add Password",
        "es": "Agregar contraseña",
      } +
      {
        "en": "Edit Password",
        "es": "Editar contraseña",
      } +
      {
        "en": "Delete password?",
        "es": "¿Eliminar contraseña?",
      } +
      {
        "en": "Password deleted",
        "es": "Contraseña eliminada",
      } +
      {
        "en": "Password copied",
        "es": "Contraseña copiada",
      } +
      {
        "en": "User copied",
        "es": "Usuario copiado",
      } +
      {
        "en": "User",
        "es": "Usuario",
      } +
      {
        "en": "Title",
        "es": "Título",
      } +
      {
        "en": "Username",
        "es": "Usuario",
      } +
      {
        "en": "Website",
        "es": "Sitio web",
      } +
      {
        "en": "New Password",
        "es": "Nueva contraseña",
      } +
      {
        "en": "Confirm Password",
        "es": "Confirmar contraseña",
      } +
      {
        "en": "Current Password",
        "es": "Contraseña actual",
      } +
      {
        "en": "Please enter a title",
        "es": "Por favor ingresa un título",
      } +
      {
        "en": "Please enter a password",
        "es": "Por favor ingresa una contraseña",
      } +
      {
        "en": "Please enter a username",
        "es": "Por favor ingresa un usuario",
      } +
      {
        "en": "Website must start with http:// or https://",
        "es": "El sitio web debe comenzar con http:// o https://",
      } +
      {
        "en": "Please fix the highlighted fields",
        "es": "Por favor corrige los campos marcados",
      } +
      {
        "en": "Password created successfully",
        "es": "Contraseña creada exitosamente",
      } +
      {
        "en": "Create Password",
        "es": "Crear contraseña",
      } +
      {
        "en": "Save Changes",
        "es": "Guardar cambios",
      } +
      {
        "en": "Error saving password",
        "es": "Error al guardar contraseña",
      } +

      // ==================== NOTES ====================
      {
        "en": "Notes",
        "es": "Notas",
      } +
      {
        "en": "Search notes",
        "es": "Buscar notas",
      } +
      {
        "en": "No notes yet",
        "es": "Aún no hay notas",
      } +
      {
        "en": "Add Note",
        "es": "Agregar nota",
      } +
      {
        "en": "Edit Note",
        "es": "Editar nota",
      } +
      {
        "en": "Delete note?",
        "es": "¿Eliminar nota?",
      } +
      {
        "en": "Note deleted",
        "es": "Nota eliminada",
      } +
      {
        "en": "Error deleting note",
        "es": "Error al eliminar nota",
      } +
      {
        "en": "Content",
        "es": "Contenido",
      } +

      // ==================== SETTINGS ====================
      {
        "en": "Settings",
        "es": "Configuración",
      } +
      {
        "en": "Security",
        "es": "Seguridad",
      } +
      {
        "en": "Change Password",
        "es": "Cambiar contraseña",
      } +
      {
        "en": "Update your password",
        "es": "Actualiza tu contraseña",
      } +
      {
        "en": "Information",
        "es": "Información",
      } +
      {
        "en": "Application Version",
        "es": "Versión de la aplicación",
      } +
      {
        "en": "Account & Privacy",
        "es": "Cuenta y privacidad",
      } +
      {
        "en": "Account",
        "es": "Cuenta",
      } +
      {
        "en": "Delete Account",
        "es": "Eliminar cuenta",
      } +
      {
        "en": "This action cannot be undone",
        "es": "Esta acción no se puede deshacer",
      } +
      {
        "en": "Are you sure you want to delete your account? This action cannot be undone.",
        "es": "¿Estás seguro de que deseas eliminar tu cuenta? Esta acción no se puede deshacer.",
      } +
      {
        "en": "Are you sure you want to logout?",
        "es": "¿Estás seguro de que deseas cerrar sesión?",
      } +
      {
        "en": "Account deleted successfully",
        "es": "Cuenta eliminada exitosamente",
      } +
      {
        "en": "Error deleting account",
        "es": "Error al eliminar cuenta",
      } +
      {
        "en": "Please complete the new password",
        "es": "Por favor completa la nueva contraseña",
      } +
      {
        "en": "The new passwords do not match",
        "es": "Las nuevas contraseñas no coinciden",
      } +
      {
        "en": "Password must be at least 6 characters",
        "es": "La contraseña debe tener al menos 6 caracteres",
      } +
      {
        "en": "Password changed successfully",
        "es": "Contraseña cambiada exitosamente",
      } +
      {
        "en": "Failed to change password",
        "es": "Error al cambiar contraseña",
      } +
      {
        "en": "Error changing password",
        "es": "Error al cambiar contraseña",
      } +
      {
        "en": "Change",
        "es": "Cambiar",
      } +

      // ==================== DEBUG ====================
      {
        "en": "This will delete ALL local data:",
        "es": "Esto eliminará TODOS los datos locales:",
      } +
      {
        "en": "All notes",
        "es": "Todas las notas",
      } +
      {
        "en": "All passwords",
        "es": "Todas las contraseñas",
      } +
      {
        "en": "Cached credentials",
        "es": "Credenciales en caché",
      } +
      {
        "en": "Sync queue",
        "es": "Cola de sincronización",
      } +
      {
        "en": "Are you sure?",
        "es": "¿Estás seguro?",
      } +
      {
        "en": "Yes, Delete All",
        "es": "Sí, eliminar todo",
      } +
      {
        "en": "Database deleted. Restart the app.",
        "es": "Base de datos eliminada. Reinicia la aplicación.",
      } +

      // ==================== SYNC ====================
      {
        "en": "Syncing in background...",
        "es": "Sincronizando en segundo plano...",
      } +
      {
        "en": "Sync complete",
        "es": "Sincronización completa",
      } +
      {
        "en": "Sync failed",
        "es": "Error de sincronización",
      } +
      {
        "en": "Offline",
        "es": "Sin conexión",
      } +
      {
        "en": "Online",
        "es": "En línea",
      } +
      {
        "en": "Sync Panel",
        "es": "Panel de Sincronización",
      } +
      {
        "en": "Registrations",
        "es": "Registros",
      } +
      {
        "en": "Sync Now",
        "es": "Sincronizar Ahora",
      } +
      {
        "en": "Syncing...",
        "es": "Sincronizando...",
      } +
      {
        "en": "Sync Successful",
        "es": "Sincronización Exitosa",
      } +
      {
        "en": "Sync Error",
        "es": "Error en Sincronización",
      } +
      {
        "en": "pending",
        "es": "pendiente",
      } +

      // ==================== AUTH ADDITIONAL ====================
      {
        "en": "Welcome",
        "es": "Bienvenido",
      } +
      {
        "en": "Sign in to your account",
        "es": "Inicia sesión en tu cuenta",
      } +
      {
        "en": "Sign In",
        "es": "Iniciar sesión",
      } +
      {
        "en": "Don't have an account? ",
        "es": "¿No tienes una cuenta? ",
      } +
      {
        "en": "Sign Up",
        "es": "Registrarse",
      } +
      {
        "en": "Already have an account? ",
        "es": "¿Ya tienes una cuenta? ",
      } +
      {
        "en": "Create account",
        "es": "Crear cuenta",
      } +
      {
        "en": "Please complete email and password",
        "es": "Por favor completa el correo y contraseña",
      } +
      {
        "en": "Login failed",
        "es": "Error al iniciar sesión",
      } +

      // ==================== NOTES ADDITIONAL ====================
      {
        "en": "Delete Note?",
        "es": "¿Eliminar nota?",
      } +
      {
        "en": "Are you sure you want to delete",
        "es": "¿Estás seguro de que deseas eliminar",
      } +
      {
        "en": "No have notes yet",
        "es": "Aún no tienes notas",
      } +
      {
        "en": "New Note",
        "es": "Nueva nota",
      } +
      {
        "en": "A note with this title already exists",
        "es": "Ya existe una nota con este título",
      } +
      {
        "en": "Please enter the content",
        "es": "Por favor ingresa el contenido",
      } +
      {
        "en": "Error loading notes",
        "es": "Error al cargar notas",
      } +

      // ==================== PASSWORDS ADDITIONAL ====================
      {
        "en": "Delete Password?",
        "es": "¿Eliminar contraseña?",
      } +
      {
        "en": "No passwords yet",
        "es": "Aún no hay contraseñas",
      } +
      {
        "en": "Show Password",
        "es": "Mostrar contraseña",
      } +
      {
        "en": "Hide Password",
        "es": "Ocultar contraseña",
      } +

      // ==================== HOME ====================
      {
        "en": "No data yet",
        "es": "Aún no hay datos",
      } +

      // ==================== BIOMETRIC ====================
      {
        "en": "Biometric Authentication",
        "es": "Autenticación biométrica",
      } +
      {
        "en": "Use %s to unlock app",
        "es": "Usar %s para desbloquear",
      } +
      {
        "en": "App Locked",
        "es": "App bloqueada",
      } +
      {
        "en": "Authenticate to continue",
        "es": "Autentícate para continuar",
      } +
      {
        "en": "Authenticate to access ThisJowi",
        "es": "Autentícate para acceder a ThisJowi",
      } +
      {
        "en": "Authenticate to enable biometric lock",
        "es": "Autentícate para activar el bloqueo biométrico",
      } +
      {
        "en": "Authenticating...",
        "es": "Autenticando...",
      } +
      {
        "en": "Tap to use %s",
        "es": "Toca para usar %s",
      } +
      {
        "en": "Biometric not available",
        "es": "Biometría no disponible",
      } +
      {
        "en": "Your device does not support biometric authentication",
        "es": "Tu dispositivo no soporta autenticación biométrica",
      } +
      {
        "en": "Biometric enabled",
        "es": "Biometría activada",
      } +
      {
        "en": "Biometric disabled",
        "es": "Biometría desactivada",
      } +
      {
        "en": "Authentication failed",
        "es": "Autenticación fallida",
      } +
      {
        "en": "Please try again",
        "es": "Por favor intenta de nuevo",
      } +

      // ==================== ONBOARDING ====================
      {
        "en": "Welcome to ThisJowi",
        "es": "Bienvenido a ThisJowi",
      } +
      {
        "en": "Your secure password manager",
        "es": "Tu gestor de contraseñas seguro",
      } +
      {
        "en": "Secure Storage",
        "es": "Almacenamiento seguro",
      } +
      {
        "en": "All your passwords encrypted and safe",
        "es": "Todas tus contraseñas cifradas y seguras",
      } +
      {
        "en": "Offline Access",
        "es": "Acceso sin conexión",
      } +
      {
        "en": "Access your data anytime, anywhere",
        "es": "Accede en cualquier momento y lugar",
      } +
      {
        "en": "Cloud Sync",
        "es": "Sincronización en la nube",
      } +
      {
        "en": "Add your first password or note",
        "es": "Agregar tu primera contraseña o nota",
      } +
      {
        "en": "Keep your data synced across all devices",
        "es": "Mantén tus datos sincronizados en todos tus dispositivos",
      } +
      {
        "en": "Biometric Security",
        "es": "Seguridad biométrica",
      } +
      {
        "en": "Quick and secure access with your fingerprint",
        "es": "Acceso rápido y seguro con tu huella digital",
      } +
      {
        "en": "Get Started",
        "es": "Comenzar",
      } +
      {
        "en": "Next",
        "es": "Siguiente",
      } +
      {
        "en": "Skip",
        "es": "Omitir",
      } +
      {
        "en": "Back",
        "es": "Atrás",
      };

  String get i18n => localize(this, _t);
  
  String i18nFor(String locale) => i18n;

  String fill(List<Object> params) => localizeFill(this, params);
}
