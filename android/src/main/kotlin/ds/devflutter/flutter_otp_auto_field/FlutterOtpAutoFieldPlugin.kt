package ds.devflutter.flutter_otp_auto_field

import AppSignatureHelper
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterOtpAutoFieldPlugin */
class FlutterOtpAutoFieldPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

  private lateinit var channel: MethodChannel
  private lateinit var applicationContext: Context
  private var activity: Activity? = null
  private var smsReceiver: BroadcastReceiver? = null

  companion object {
    private const val TAG = "FlutterOtpAutoField"
  }

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "flutter_otp_auto_field")
    channel.setMethodCallHandler(this)
    applicationContext = binding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "startListening" -> startSmsRetriever(result)
      "getAppSignature" -> {
        val appHash = activity?.applicationContext?.let {
          AppSignatureHelper(it).getAppSignature()
        }
        result.success(appHash ?: "")
      }
      else -> result.notImplemented()
    }
  }

  /** Start SMS Retriever API */
  private fun startSmsRetriever(result: Result) {
    val client = SmsRetriever.getClient(applicationContext)
    val task = client.startSmsRetriever()

    task.addOnSuccessListener {
      Log.d(TAG, "SMS Retriever started")
      registerSmsReceiver()
      result.success("listening")
    }

    task.addOnFailureListener {
      Log.e(TAG, "Failed to start SMS Retriever", it)
      result.error("SMS_START_FAILED", "Failed to start SMS Retriever", it.message)
    }
  }

  /** Register BroadcastReceiver */
  private fun registerSmsReceiver() {
    unregisterSmsReceiver()

    smsReceiver = object : BroadcastReceiver() {
      override fun onReceive(context: Context, intent: Intent) {
        if (SmsRetriever.SMS_RETRIEVED_ACTION != intent.action) return

        val extras = intent.extras ?: return

        val status = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
          extras.getParcelable(SmsRetriever.EXTRA_STATUS, Status::class.java)
        } else {
          @Suppress("DEPRECATION")
          extras.getParcelable(SmsRetriever.EXTRA_STATUS)
        }

        if (status?.statusCode == CommonStatusCodes.SUCCESS) {
          val message = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.getParcelable(SmsRetriever.EXTRA_SMS_MESSAGE, String::class.java)
          } else {
            @Suppress("DEPRECATION")
            extras.get(SmsRetriever.EXTRA_SMS_MESSAGE) as? String
          }

          val otp = extractOtp(message.orEmpty())
          Log.d(TAG, "OTP received: $otp")

          channel.invokeMethod("onOtpReceived", otp)

          // Auto-restart to keep listening
          unregisterSmsReceiver()
          startSmsRetriever(object : Result {
            override fun success(result: Any?) {
              Log.d(TAG, "SMS Retriever restarted")
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
              Log.e(TAG, "Failed to restart SMS Retriever: $errorMessage")
            }

            override fun notImplemented() {}
          })
        }
      }
    }

    val intentFilter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        activity?.registerReceiver(smsReceiver, intentFilter, Context.RECEIVER_EXPORTED)
      } else {
        activity?.registerReceiver(smsReceiver, intentFilter)
      }
    } catch (e: Exception) {
      Log.e(TAG, "Failed to register receiver", e)
    }
  }

  /** Unregister receiver safely */
  private fun unregisterSmsReceiver() {
    if (smsReceiver != null) {
      try {
        activity?.unregisterReceiver(smsReceiver)
      } catch (e: Exception) {
        Log.w(TAG, "Receiver already unregistered")
      } finally {
        smsReceiver = null
      }
    }
  }

  /** Extract 4-6 digit OTP from message */
  private fun extractOtp(message: String): String? {
    val regex = Regex("\\b\\d{4,6}\\b")
    return regex.find(message)?.value
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    unregisterSmsReceiver()
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    unregisterSmsReceiver()
    activity = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    unregisterSmsReceiver()
  }
}
