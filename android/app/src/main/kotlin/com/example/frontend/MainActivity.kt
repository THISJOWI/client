package com.example.frontend

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.thisjowi/autofill"
    
    // Pending autofill data
    private var pendingAutofillPackage: String? = null
    private var pendingAutofillSave: Boolean = false
    private var pendingSaveUsername: String? = null
    private var pendingSavePassword: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAutofillServiceEnabled" -> {
                    result.success(isAutofillServiceEnabled())
                }
                "openAutofillSettings" -> {
                    openAutofillSettings()
                    result.success(true)
                }
                "hasAutofillSupport" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }
                "getPendingAutofillRequest" -> {
                    val data = mapOf(
                        "package" to pendingAutofillPackage,
                        "isSaveRequest" to pendingAutofillSave,
                        "username" to pendingSaveUsername,
                        "password" to pendingSavePassword
                    )
                    // Clear pending data after sending
                    pendingAutofillPackage = null
                    pendingAutofillSave = false
                    pendingSaveUsername = null
                    pendingSavePassword = null
                    result.success(data)
                }
                "provideAutofillCredentials" -> {
                    val username = call.argument<String>("username")
                    val password = call.argument<String>("password")
                    // The credentials will be returned via the activity result
                    // For now, we store them to be used in the autofill response
                    AutofillCredentialStore.username = username
                    AutofillCredentialStore.password = password
                    AutofillCredentialStore.hasCredentials = true
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.getBooleanExtra("autofill_request", false)) {
            pendingAutofillPackage = intent.getStringExtra("target_package")
            pendingAutofillSave = false
        } else if (intent.getBooleanExtra("autofill_save", false)) {
            pendingAutofillPackage = intent.getStringExtra("target_package")
            pendingAutofillSave = true
            pendingSaveUsername = intent.getStringExtra("username")
            pendingSavePassword = intent.getStringExtra("password")
        }
    }

    private fun isAutofillServiceEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        val autofillManager = getSystemService(AutofillManager::class.java)
        return autofillManager?.hasEnabledAutofillServices() == true
    }

    private fun openAutofillSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                data = android.net.Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
}

/**
 * Singleton to store credentials for autofill response
 */
object AutofillCredentialStore {
    var username: String? = null
    var password: String? = null
    var hasCredentials: Boolean = false
    
    fun clear() {
        username = null
        password = null
        hasCredentials = false
    }
}
