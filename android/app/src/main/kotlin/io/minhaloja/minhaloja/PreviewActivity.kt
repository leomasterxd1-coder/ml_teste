package io.minhaloja.minhaloja

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.viewpager2.widget.ViewPager2

class PreviewActivity : AppCompatActivity() {
    private lateinit var pager: ViewPager2
    private lateinit var btnShare: Button
    private lateinit var overlayLock: View
    private var isGenerating = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_preview)
        pager = findViewById(R.id.pagerPreview)
        btnShare = findViewById(R.id.btnSharePdf)
        overlayLock = findViewById(R.id.overlayLock)
        val btnBack = findViewById<View>(R.id.btnBackPreview)
        btnBack.setOnClickListener { finish() }
        btnShare.setOnClickListener {
            if (isGenerating) return@setOnClickListener
            isGenerating = true
            overlayLock.visibility = View.VISIBLE
            btnShare.isEnabled = false
            btnShare.text = "GERANDO PDF..."
            // Simula geração nativa com trava de tela
            window.decorView.postDelayed({
                isGenerating = false
                overlayLock.visibility = View.GONE
                btnShare.isEnabled = true
                btnShare.text = "COMPARTILHAR PDF"
            }, 2000)
        }
        // Carrega preview nativo via MainActivity.composePageFromPdfs se necessário
    }
}
