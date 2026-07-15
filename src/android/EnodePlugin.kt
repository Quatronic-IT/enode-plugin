package com.quatronic.enode

import android.app.Activity
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import io.enode.link.LinkKit
import org.apache.cordova.CallbackContext
import org.apache.cordova.CordovaPlugin
import org.json.JSONArray
import org.json.JSONObject

class EnodePlugin : CordovaPlugin() {

    private var pendingCallback: CallbackContext? = null
    private lateinit var resultLauncher: ActivityResultLauncher<Intent>
    private var initializationError: String? = null
    private var previousNightMode: Int? = null

    companion object {
        private const val ACTION_OPEN_LINK_UI = "openLinkUI"
    }

    override fun pluginInitialize() {
        try {
            val activity = cordova.activity as AppCompatActivity
            resultLauncher = activity.registerForActivityResult(
                ActivityResultContracts.StartActivityForResult()
            ) { result ->
                // Night mode is process-wide (AppCompatDelegate), not scoped to LinkKit's
                // activity, so whatever was active before this call is restored here rather
                // than left overridden for the rest of the app's lifetime.
                previousNightMode?.let {
                    AppCompatDelegate.setDefaultNightMode(it)
                    previousNightMode = null
                }

                val callbackContext = pendingCallback ?: return@registerForActivityResult
                pendingCallback = null
                when (result.resultCode) {
                    Activity.RESULT_OK -> callbackContext.success(successResult())
                    else -> {
                        val errorCode = result.data?.getStringExtra(LinkKit.ERROR_CODE)
                        val errorDetails = result.data?.getStringExtra(LinkKit.ERROR_DETAILS)

                        android.util.Log.d("EnodePlugin", "resultCode=${result.resultCode} errorCode='$errorCode' errorDetails='$errorDetails'")

                        if (errorCode == "USER_INTERACTION") {
                            callbackContext.success(cancelledResult())
                        } else {
                            callbackContext.error(errorResult(errorCode ?: "UNKNOWN", errorDetails))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // No callback is in flight yet at plugin-init time, so a failure here can't be
            // reported to JS directly - it's surfaced instead on the first execute() call,
            // which checks initializationError before doing anything else.
            initializationError = e.message ?: "Failed to initialize EnodePlugin"
        }
    }

    override fun execute(action: String, args: JSONArray, callbackContext: CallbackContext): Boolean {
        if (action != ACTION_OPEN_LINK_UI) return false

        try {
            initializationError?.let { throw IllegalStateException(it) }
            val linkToken = args.getString(0)
            val themeMode = args.optString(1, "system")
            pendingCallback = callbackContext

            previousNightMode = AppCompatDelegate.getDefaultNightMode()
            AppCompatDelegate.setDefaultNightMode(nightModeFor(themeMode))

            val intent = Intent(cordova.activity, LinkKit::class.java)
            intent.putExtra(LinkKit.INTENT_LINK_TOKEN, linkToken)
            resultLauncher.launch(intent)
        } catch (e: Exception) {
            previousNightMode?.let {
                AppCompatDelegate.setDefaultNightMode(it)
                previousNightMode = null
            }
            pendingCallback = null
            callbackContext.error(errorResult("PLUGIN_ERROR", e.message ?: "Failed to open Link UI"))
        }
        return true
    }

    private fun nightModeFor(themeMode: String) = when (themeMode) {
        "light" -> AppCompatDelegate.MODE_NIGHT_NO
        "dark" -> AppCompatDelegate.MODE_NIGHT_YES
        else -> AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM
    }

    private fun successResult() = JSONObject().apply {
        put("status", "success")
    }

    private fun cancelledResult() = JSONObject().apply {
        put("status", "cancelled")
    }

    private fun errorResult(code: String, details: String?) = JSONObject().apply {
        put("status", "error")
        put("code", code)
        put("message", details ?: "Unknown error")
    }
}
