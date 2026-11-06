package com.useadvance.use_advance_picture_dictionary_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.useadvance.picture_dict/interlink"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchAndroidCompanion" -> {
                    val packageName = call.argument<String>("package") ?: "com.useadvance.dictionary"
                    val word = call.argument<String>("word") ?: ""
                    try {
                        val pm = packageManager
                        // 1. Try launching with explicit package intent for the URI
                        val deepLinkUri = Uri.parse("useadvancedict://word?term=" + Uri.encode(word))
                        val explicitIntent = Intent(Intent.ACTION_VIEW, deepLinkUri)
                        explicitIntent.setPackage(packageName)
                        explicitIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        if (explicitIntent.resolveActivity(pm) != null) {
                            startActivity(explicitIntent)
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        // 2. Fallback: Launch via package launch intent (works even if target lacks custom URI scheme)
                        val launchIntent = pm.getLaunchIntentForPackage(packageName)
                        if (launchIntent != null) {
                            launchIntent.data = deepLinkUri
                            launchIntent.putExtra("term", word)
                            launchIntent.putExtra("word", word)
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(launchIntent)
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        result.success(false)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isCompanionInstalled" -> {
                    val packageName = call.argument<String>("package") ?: "com.useadvance.dictionary"
                    try {
                        packageManager.getPackageInfo(packageName, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
