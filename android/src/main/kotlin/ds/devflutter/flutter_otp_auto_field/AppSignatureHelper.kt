import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.util.Base64
import android.util.Log
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException
import java.util.*

class AppSignatureHelper(private val context: Context) {

    companion object {
        private const val HASH_TYPE = "SHA-256"
        private const val NUM_HASHED_BYTES = 9
        private const val NUM_BASE64_CHAR = 11
        private const val TAG = "FlutterOtpAutoFieldPlugin:AppSignatureHelper"
    }

    /**
     * Returns the app's SMS Retriever-compatible hash string.
     */
    @SuppressLint("PackageManagerGetSignatures")
    fun getAppSignature(): String {
        val signatures = ArrayList<String>()
        try {
            val packageName = context.packageName
            val packageManager = context.packageManager
            val sigs = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                    .signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
            }

            sigs?.forEach { signature ->
                generateHash(packageName, signature.toCharsString())?.let {
                    signatures.add(it)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to get app signature hash", e)
        }

        return signatures.firstOrNull() ?: ""
    }

    private fun generateHash(packageName: String, signature: String): String? {
        return try {
            val messageDigest = MessageDigest.getInstance(HASH_TYPE)
            messageDigest.update("$packageName $signature".toByteArray(StandardCharsets.UTF_8))
            val digest = messageDigest.digest().copyOfRange(0, NUM_HASHED_BYTES)
            Base64.encodeToString(digest, Base64.NO_PADDING or Base64.NO_WRAP)
                .substring(0, NUM_BASE64_CHAR)
        } catch (e: NoSuchAlgorithmException) {
            Log.e(TAG, "NoSuchAlgorithmException: $HASH_TYPE", e)
            null
        }
    }
}
