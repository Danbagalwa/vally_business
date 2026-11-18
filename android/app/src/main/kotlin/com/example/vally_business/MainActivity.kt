package com.example.vally_business

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vally/whatsapp")
            .setMethodCallHandler { appel, resultat ->
                if (appel.method != "partagerFichier") {
                    resultat.notImplemented()
                    return@setMethodCallHandler
                }
                val chemin = appel.argument<String>("chemin")
                if (chemin == null) {
                    resultat.success(false)
                    return@setMethodCallHandler
                }
                resultat.success(
                    ouvrirWhatsApp(
                        File(chemin),
                        appel.argument<String>("numero"),
                        appel.argument<String>("texte"),
                    )
                )
            }
    }

    /**
     * Ouvre WhatsApp (ou WhatsApp Business) sur la discussion du client,
     * avec le PDF joint et le message pré-rempli. L'envoi reste à faire
     * par la personne (bouton « Envoyer » de WhatsApp).
     * Le « jid » (numéro@s.whatsapp.net) cible le contact : non documenté
     * par WhatsApp, mais accepté par ses versions actuelles.
     */
    private fun ouvrirWhatsApp(fichier: File, numero: String?, texte: String?): Boolean {
        val uri = FileProvider.getUriForFile(this, "$packageName.factures", fichier)
        for (paquet in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val intention = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                setPackage(paquet)
                putExtra(Intent.EXTRA_STREAM, uri)
                if (texte != null) putExtra(Intent.EXTRA_TEXT, texte)
                if (!numero.isNullOrBlank()) putExtra("jid", "$numero@s.whatsapp.net")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                startActivity(intention)
                return true
            } catch (e: ActivityNotFoundException) {
                // Essai suivant (WhatsApp Business), sinon menu de partage.
            }
        }
        return false
    }
}
