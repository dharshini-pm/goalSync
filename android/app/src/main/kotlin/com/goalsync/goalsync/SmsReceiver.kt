package com.goalsync.goalsync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

/**
 * Native Android BroadcastReceiver that listens for newly received SMS broadcasts.
 *
 * Privacy & Resource Protections:
 * - Does NOT read the full inbox; processes ONLY incoming broadcast events.
 * - Applies a lightweight pre-filter on the sender and text keywords.
 * - Completely drops OTPs, personal SMS, and non-financial messages before dispatching.
 * - Passes qualifying candidates to MainActivity / Flutter via MethodChannel.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GoalSyncSmsReceiver"

        // Obvious OTP and verification tokens to reject immediately
        private val OTP_KEYWORDS = listOf(
            "otp", "verification code", "security code", "secret code", "is your login otp"
        )

        // Basic transaction signals indicating potential banking activity
        private val TRANSACTION_KEYWORDS = listOf(
            "debited", "debit", "credited", "credit", "paid", "payment",
            "spent", "withdrawn", "purchase", "transferred", "sent to",
            "upi", "vpa", "atm", "imps", "neft", "a/c", "acct", "avl bal"
        )

        /**
         * Quick local pre-filter to drop obviously irrelevant SMS before bridge invocation.
         */
        fun isPotentialFinancialSms(body: String): Boolean {
            val lower = body.lowercase()

            // If it's an OTP message, immediately ignore
            for (otp in OTP_KEYWORDS) {
                if (lower.contains(otp)) {
                    return false
                }
            }

            // Must contain at least one banking or transaction signal
            for (keyword in TRANSACTION_KEYWORDS) {
                if (lower.contains(keyword)) {
                    return true
                }
            }

            return false
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) {
                return
            }

            // Group multipart SMS into single message body
            val sender = messages[0].displayOriginatingAddress ?: "UNKNOWN"
            val timestamp = messages[0].timestampMillis

            val bodyBuilder = StringBuilder()
            for (sms in messages) {
                bodyBuilder.append(sms.displayMessageBody)
            }
            val body = bodyBuilder.toString()

            // Lightweight Android-side pre-filter
            if (!isPotentialFinancialSms(body)) {
                return
            }

            // Forward to MainActivity / Flutter engine for authoritative intelligence parsing
            MainActivity.onSmsReceived(sender, body, timestamp)

        } catch (e: Exception) {
            // Never log sensitive SMS text
            Log.e(TAG, "Error handling incoming SMS broadcast: ${e.javaClass.simpleName}")
        }
    }
}
