package com.useadvance.use_advance_picture_dictionary_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.useadvance.picture_dict/interlink"
    private val ASSET_CHANNEL = "com.useadvance.picture_dict/asset_pack"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Asset pack loader channel for Play Asset Delivery (PAD)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCardBytes" -> {
                    val rawPath = call.argument<String>("path")
                    if (rawPath != null) {
                        try {
                            // Strip leading prefixes
                            var cleanPath = rawPath.replace("\\", "/").trim()
                            cleanPath = cleanPath.removePrefix("file://").removePrefix("/")
                            cleanPath = cleanPath.removePrefix("assets/").removePrefix("/")

                            val candidatePaths = mutableListOf(cleanPath)
                            val filename = cleanPath.substringAfterLast('/')
                            if (filename.isNotEmpty()) {
                                candidatePaths.add("cards/$filename")
                                candidatePaths.add("flutter_assets/assets/cards/$filename")
                            }

                            var bytes: ByteArray? = null
                            for (p in candidatePaths) {
                                try {
                                    val inputStream: InputStream = context.assets.open(p)
                                    bytes = inputStream.readBytes()
                                    inputStream.close()
                                    if (bytes != null && bytes.isNotEmpty()) break
                                } catch (_: Exception) {
                                }
                            }

                            if (bytes != null && bytes.isNotEmpty()) {
                                result.success(bytes)
                            } else {
                                result.error("NOT_FOUND", "Asset not found: $rawPath", null)
                            }
                        } catch (e: Exception) {
                            result.error("NOT_FOUND", "Asset not found: $rawPath (${e.message})", null)
                        }
                    } else {
                        result.error("INVALID_ARG", "Path parameter was null", null)
                    }
                }
                "checkCardExists" -> {
                    val rawPath = call.argument<String>("path")
                    if (rawPath != null) {
                        try {
                            var cleanPath = rawPath.replace("\\", "/").trim()
                            cleanPath = cleanPath.removePrefix("file://").removePrefix("/")
                            cleanPath = cleanPath.removePrefix("assets/").removePrefix("/")
                            val candidatePaths = listOf(cleanPath, "cards/${cleanPath.substringAfterLast('/')}")
                            var found = false
                            for (p in candidatePaths) {
                                try {
                                    val inputStream = context.assets.open(p)
                                    inputStream.close()
                                    found = true
                                    break
                                } catch (_: Exception) {
                                }
                            }
                            result.success(found)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Companion app interlink channel
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
