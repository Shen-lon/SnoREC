package dev.shenlon.snorec

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        return cache.get(ENGINE_ID) ?: FlutterEngine(context.applicationContext).also {
            RecordingBridge(context.applicationContext, it.dartExecutor.binaryMessenger)
            cache.put(ENGINE_ID, it)
        }
    }

    // Keep the microphone stream and Dart timers alive when the screen closes.
    override fun shouldDestroyEngineWithHost() = false

    companion object {
        const val ENGINE_ID = "snorec_session"
    }
}
