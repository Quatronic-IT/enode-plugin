package com.quatronic.enode

import android.app.Activity
import android.content.Intent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import io.enode.link.LinkKit
import org.apache.cordova.CallbackContext
import org.apache.cordova.CordovaPlugin
import org.json.JSONArray
import org.json.JSONObject

class EnodePlugin : CordovaPlugin() {

    private var pendingCallback: CallbackContext? = null
    private lateinit var resultLauncher: ActivityResultLauncher<Intent>
    private var initializationError: String? = null

    companion object {
        private const val ACTION_OPEN_LINK_UI = "openLinkUI"
    }

    override fun pluginInitialize() {
        try {
            val activity = cordova.activity as AppCompatActivity
            resultLauncher = activity.registerForActivityResult(
                ActivityResultContracts.StartActivityForResult()
            ) { result ->
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
            pendingCallback = callbackContext
            val intent = Intent(cordova.activity, LinkKit::class.java)
            intent.putExtra(LinkKit.INTENT_LINK_TOKEN, linkToken)
            resultLauncher.launch(intent)
        } catch (e: Exception) {
            pendingCallback = null
            callbackContext.error(errorResult("PLUGIN_ERROR", e.message ?: "Failed to open Link UI"))
        }
        return true
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
