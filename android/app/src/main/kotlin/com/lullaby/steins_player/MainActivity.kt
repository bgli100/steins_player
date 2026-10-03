package com.lullaby.steins_player

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Match the OHOS client: full screen (edge-to-edge) with the system
        // bars hidden.
        window.attributes.layoutInDisplayCutoutMode =
            WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CUTOUT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCutoutRects") {
                    result.success(cutOutRects())
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * The camera cut-out in Flutter logical pixels relative to the Flutter
     * view, as [left, top, right, bottom] quads. Empty when the platform does
     * not report one.
     */
    private fun cutOutRects(): List<List<Double>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return emptyList()
        val insets = window?.decorView?.rootWindowInsets ?: return emptyList()
        val cutout = insets.displayCutout ?: return emptyList()
        val decor = window.decorView
        val location = IntArray(2)
        decor.getLocationOnScreen(location)
        val density = resources.displayMetrics.density.toDouble()
        return cutout.boundingRects.map { rect ->
            listOf(
                (rect.left - location[0]) / density,
                (rect.top - location[1]) / density,
                (rect.right - location[0]) / density,
                (rect.bottom - location[1]) / density,
            )
        }
    }

    private companion object {
        const val CUTOUT_CHANNEL = "lullaby/display_cutout"
    }
}
