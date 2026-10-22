package br.com.conectepalavras.caca_palavra

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.SoundPool
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pool: SoundPool? = null
    private val sounds = mutableMapOf<String, Int>()
    private val ready = mutableSetOf<Int>()
    private val streams = mutableListOf<Int>()
    private var foreground = true
    private val handler = Handler(Looper.getMainLooper())
    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < AudioManager.AUDIOFOCUS_GAIN) stopSounds()
    }
    private val focusRequest by lazy {
        if (Build.VERSION.SDK_INT >= 26) AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener).build() else null
    }
    private val releaseFocus = Runnable { abandonFocus() }
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { stopSounds() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY), RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "conecte_palavras/feedback")
            .setMethodCallHandler { call, result ->
                // Unsupported hardware or an unavailable asset is non-fatal.
                try {
                    when (call.method) {
                        "prepare" -> prepareSounds()
                        "sound" -> playSound(call.arguments as? String ?: "")
                        "haptic" -> if (foreground) {
                            window.decorView.performHapticFeedback(
                                if (call.arguments == true && Build.VERSION.SDK_INT >= 30)
                                    HapticFeedbackConstants.CONFIRM
                                else HapticFeedbackConstants.CLOCK_TICK)
                        }
                        "stop" -> stopSounds()
                        "dispose" -> releaseSounds()
                        else -> { result.notImplemented(); return@setMethodCallHandler }
                    }
                    result.success(null)
                } catch (_: Exception) { result.success(null) }
            }
    }

    private fun prepareSounds() {
        if (pool != null) return
        val player = SoundPool.Builder().setMaxStreams(2).setAudioAttributes(attributes).build()
        pool = player
        player.setOnLoadCompleteListener { _, id, status -> if (status == 0) ready.add(id) }
        val loader = FlutterInjector.instance().flutterLoader()
        for (name in listOf("select", "undo", "shuffle", "correct", "extra", "invalid", "reveal", "victory", "coins")) {
            try {
                assets.openFd(loader.getLookupKeyForAsset("assets/audio/$name.wav")).use {
                    sounds[name] = player.load(it, 1)
                }
            } catch (_: Exception) { /* Continue loading the remaining effects. */ }
        }
    }

    private fun playSound(name: String) {
        if (!foreground) return
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (manager.ringerMode != AudioManager.RINGER_MODE_NORMAL ||
            manager.getStreamVolume(AudioManager.STREAM_MUSIC) == 0) return
        val id = sounds[name] ?: return
        if (!ready.contains(id)) return // Drop unprepared effects; never queue a gesture.
        val important = name == "victory" || name == "reveal"
        if (important) stopSounds()
        val focus = if (Build.VERSION.SDK_INT >= 26) audioManager.requestAudioFocus(focusRequest!!)
            else {
                @Suppress("DEPRECATION")
                audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            }
        if (focus != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return
        handler.removeCallbacks(releaseFocus)
        handler.postDelayed(releaseFocus, 650)
        while (streams.size >= 2) pool?.stop(streams.removeAt(0))
        pool?.play(id, 0.36f, 0.36f, if (important) 2 else 1, 0, 1f)?.let { streams.add(it) }
    }
    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        else { @Suppress("DEPRECATION") audioManager.abandonAudioFocus(focusListener) }
    }
    private fun stopSounds() {
        streams.forEach { pool?.stop(it) }; streams.clear()
        handler.removeCallbacks(releaseFocus); abandonFocus()
    }
    private fun releaseSounds() { stopSounds(); pool?.release(); pool = null; ready.clear(); sounds.clear() }
    override fun onPause() { foreground = false; stopSounds(); super.onPause() }
    override fun onResume() { super.onResume(); foreground = true }
    override fun onDestroy() {
        runCatching { unregisterReceiver(noisy) }
        releaseSounds()
        super.onDestroy()
    }
}
