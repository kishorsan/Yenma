package com.kiki.yenma

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val channelName = "yenma/sms"
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "readMessages" -> readMessages(call.arguments as? Map<*, *>, result)
                "scheduleDailySync" -> { scheduleDailySync(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun readMessages(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.READ_SMS), 77)
            result.error("permission_denied", "SMS permission is required", null)
            return
        }
        val messages = mutableListOf<Map<String, Any>>()
        val from = (arguments?.get("from") as? Number)?.toLong()
        val until = (arguments?.get("until") as? Number)?.toLong()
        val selectionParts = mutableListOf<String>()
        val selectionArgs = mutableListOf<String>()
        if (from != null) { selectionParts += "${Telephony.Sms.DATE} >= ?"; selectionArgs += from.toString() }
        if (until != null) { selectionParts += "${Telephony.Sms.DATE} < ?"; selectionArgs += until.toString() }
        contentResolver.query(Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
            selectionParts.takeIf { it.isNotEmpty() }?.joinToString(" AND "),
            selectionArgs.takeIf { it.isNotEmpty() }?.toTypedArray(), "${Telephony.Sms.DATE} DESC")?.use { cursor ->
            val address = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val body = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val date = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (cursor.moveToNext() && messages.size < 1000) {
                messages.add(mapOf("address" to (cursor.getString(address) ?: ""), "body" to (cursor.getString(body) ?: ""), "timestamp" to cursor.getLong(date)))
            }
        }
        result.success(messages)
    }

    private fun scheduleDailySync() {
        val alarm = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, DailySyncReceiver::class.java)
        val pending = PendingIntent.getBroadcast(this, 2200, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val at = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 22); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0); if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DATE, 1) }
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.timeInMillis, pending)
    }
}
