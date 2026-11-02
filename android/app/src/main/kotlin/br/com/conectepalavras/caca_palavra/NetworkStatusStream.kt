package br.com.conectepalavras.caca_palavra

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class NetworkStatusStream(context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val handler = Handler(Looper.getMainLooper())
    private val methods = MethodChannel(messenger, "conecte_palavras/network")
    private val events = EventChannel(messenger, "conecte_palavras/network_changes")
    private var sink: EventChannel.EventSink? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    init {
        methods.setMethodCallHandler { call, result ->
            if (call.method == "check") result.success(available()) else result.notImplemented()
        }
        events.setStreamHandler(this)
    }

    private fun available(): Boolean? = runCatching {
        val network = manager.activeNetwork ?: return@runCatching false
        val capabilities = manager.getNetworkCapabilities(network) ?: return@runCatching false
        validated(capabilities)
    }.getOrNull()

    private fun validated(capabilities: NetworkCapabilities): Boolean =
        capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

    private fun emit(value: Boolean?) { handler.post { sink?.success(value) } }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        onCancel(null)
        sink = eventSink
        val listener = object : ConnectivityManager.NetworkCallback() {
            private var current: Network? = null
            override fun onAvailable(network: Network) { current = network }
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                if (network == current) emit(validated(capabilities))
            }
            override fun onLost(network: Network) {
                if (network == current) { current = null; emit(false) }
            }
        }
        callback = listener
        runCatching { manager.registerDefaultNetworkCallback(listener) }
            .onFailure { callback = null }
        emit(available())
    }

    override fun onCancel(arguments: Any?) {
        callback?.let { runCatching { manager.unregisterNetworkCallback(it) } }
        callback = null
        sink = null
    }

    fun dispose() {
        onCancel(null)
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
