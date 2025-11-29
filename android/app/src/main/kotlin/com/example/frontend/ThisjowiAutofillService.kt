package com.example.frontend

import android.app.assist.AssistStructure
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.*
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import android.content.Intent
import android.app.PendingIntent
import androidx.annotation.RequiresApi
import android.util.Log

/**
 * Autofill service that provides password autofill to other apps
 * 
 * This service allows THISJOWI to act as a password manager
 * and provide credentials to other applications when requested.
 */
@RequiresApi(Build.VERSION_CODES.O)
class ThisjowiAutofillService : AutofillService() {
    
    companion object {
        private const val TAG = "ThisjowiAutofill"
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        Log.d(TAG, "onFillRequest called")
        
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess(null)
            return
        }

        val parsedFields = parseStructure(structure)
        
        if (parsedFields.usernameId == null && parsedFields.passwordId == null) {
            Log.d(TAG, "No autofillable fields found")
            callback.onSuccess(null)
            return
        }

        val packageName = structure.activityComponent?.packageName ?: ""
        Log.d(TAG, "Autofill request for package: $packageName")

        // Create intent to open the app for authentication
        val authIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("autofill_request", true)
            putExtra("target_package", packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            authIntent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val intentSender = pendingIntent.intentSender

        // Create presentation for the autofill suggestion
        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, "THISJOWI - Tap to autofill")
        }

        val responseBuilder = FillResponse.Builder()

        // Add authentication required dataset
        val datasetBuilder = Dataset.Builder()
        
        parsedFields.usernameId?.let { usernameId ->
            datasetBuilder.setValue(
                usernameId,
                null,
                presentation
            )
        }
        
        parsedFields.passwordId?.let { passwordId ->
            datasetBuilder.setValue(
                passwordId,
                null,
                presentation
            )
        }

        datasetBuilder.setAuthentication(intentSender)
        
        try {
            responseBuilder.addDataset(datasetBuilder.build())
            callback.onSuccess(responseBuilder.build())
        } catch (e: Exception) {
            Log.e(TAG, "Error building autofill response", e)
            callback.onFailure("Error building response: ${e.message}")
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        Log.d(TAG, "onSaveRequest called")
        
        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess()
            return
        }

        val parsedFields = parseStructure(structure)
        val packageName = structure.activityComponent?.packageName ?: ""

        val username = parsedFields.usernameValue
        val password = parsedFields.passwordValue

        if (username != null || password != null) {
            // Launch app to save the new credentials
            val saveIntent = Intent(this, MainActivity::class.java).apply {
                putExtra("autofill_save", true)
                putExtra("target_package", packageName)
                putExtra("username", username)
                putExtra("password", password)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(saveIntent)
        }

        callback.onSuccess()
    }

    private fun parseStructure(structure: AssistStructure): ParsedFields {
        var usernameId: AutofillId? = null
        var passwordId: AutofillId? = null
        var usernameValue: String? = null
        var passwordValue: String? = null

        for (i in 0 until structure.windowNodeCount) {
            val windowNode = structure.getWindowNodeAt(i)
            val viewNode = windowNode.rootViewNode
            parseNode(viewNode) { autofillId, autofillHints, inputType, text ->
                when {
                    isPasswordField(autofillHints, inputType) -> {
                        passwordId = autofillId
                        passwordValue = text
                    }
                    isUsernameField(autofillHints, inputType) -> {
                        usernameId = autofillId
                        usernameValue = text
                    }
                }
            }
        }

        return ParsedFields(usernameId, passwordId, usernameValue, passwordValue)
    }

    private fun parseNode(
        node: AssistStructure.ViewNode,
        callback: (AutofillId?, Array<String>?, Int, String?) -> Unit
    ) {
        val autofillId = node.autofillId
        val autofillHints = node.autofillHints
        val inputType = node.inputType
        val text = node.text?.toString()

        if (autofillId != null) {
            callback(autofillId, autofillHints, inputType, text)
        }

        for (i in 0 until node.childCount) {
            parseNode(node.getChildAt(i), callback)
        }
    }

    private fun isPasswordField(hints: Array<String>?, inputType: Int): Boolean {
        if (hints != null) {
            for (hint in hints) {
                if (hint.contains("password", ignoreCase = true)) {
                    return true
                }
            }
        }
        // Check input type for password
        val isPassword = (inputType and android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD) != 0 ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD) != 0 ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD) != 0
        return isPassword
    }

    private fun isUsernameField(hints: Array<String>?, inputType: Int): Boolean {
        if (hints != null) {
            for (hint in hints) {
                if (hint.contains("username", ignoreCase = true) ||
                    hint.contains("email", ignoreCase = true) ||
                    hint.contains("login", ignoreCase = true)
                ) {
                    return true
                }
            }
        }
        // Check input type for email
        val isEmail = (inputType and android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS) != 0 ||
                (inputType and android.text.InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS) != 0
        return isEmail
    }

    private data class ParsedFields(
        val usernameId: AutofillId?,
        val passwordId: AutofillId?,
        val usernameValue: String?,
        val passwordValue: String?
    )
}
