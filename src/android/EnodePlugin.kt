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

    companion object {
        private const val ACTION_OPEN_LINK_UI = "openLinkUI"
    }

    override fun pluginInitialize() {
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

                    if (!errorCode.isNullOrBlank()) {
                        callbackContext.success(errorResult(errorCode, errorDetails))
                    } else {
                        callbackContext.success(cancelledResult())
                    }
                }
            }
        }
    }

    override fun execute(action: String, args: JSONArray, callbackContext: CallbackContext): Boolean {
        if (action != ACTION_OPEN_LINK_UI) return false

        val linkToken: String
        try {
            linkToken = args.getString(0)
        } catch (e: Exception) {
            callbackContext.error(errorResult("400", e.message ?: "Invalid arguments"))
            return true
        }

        pendingCallback = callbackContext
        val intent = Intent(cordova.activity, LinkKit::class.java)
        intent.putExtra(LinkKit.INTENT_LINK_TOKEN, linkToken)
        resultLauncher.launch(intent)
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
