package io.minhaloja.minhaloja

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.os.Bundle
import android.os.ParcelFileDescriptor
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import kotlin.math.ceil
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val CHANNEL = "minhaloja/pdf"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Captura qualquer exceção Java/Kotlin não tratada (incluindo OOM)
        // em arquivo acessível, antes do handler padrão do sistema.
        val prevHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { t, e ->
            try {
                val dir = getExternalFilesDir(null) ?: filesDir
                File(dir, "ultimo_crash_native.txt").appendText(
                    "[${System.currentTimeMillis()}] thread=${t.name}\n" +
                        android.util.Log.getStackTraceString(e) + "\n\n"
                )
            } catch (_: Throwable) {
            }
            prevHandler?.uncaughtException(t, e)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "renderPdfToRgba" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val w = call.argument<Int>("w") ?: 0
                        val h = call.argument<Int>("h") ?: 0
                        if (bytes == null || w <= 0 || h <= 0) {
                            result.error("BAD_ARGS", "bytes/w/h invalid", null)
                            return@setMethodCallHandler
                        }
                        // Fora da main thread: evita ANR se o usuário tocar
                        // durante o render.
                        Thread {
                            try {
                                val rgba = renderPdfToRgba(bytes, w, h)
                                runOnUiThread {
                                    try {
                                        if (rgba == null) {
                                            result.error("RENDER_FAIL", "null bitmap", null)
                                        } else {
                                            result.success(rgba)
                                        }
                                    } catch (_: Throwable) {
                                    }
                                }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    try {
                                        result.error("EXC", t.message, null)
                                    } catch (_: Throwable) {
                                    }
                                }
                            }
                        }.start()
                    }
                    "composePage" -> {
                        @Suppress("UNCHECKED_CAST")
                        val pdfsRaw = call.argument<List<Any>>("pdfs")
                        val pdfs = pdfsRaw?.mapNotNull { it as? ByteArray } ?: emptyList()
                        val cols = call.argument<Int>("cols") ?: 1
                        val rows = call.argument<Int>("rows") ?: 1
                        val cellW = call.argument<Int>("cellW") ?: 0
                        val cellH = call.argument<Int>("cellH") ?: 0
                        val overlayName = call.argument<String>("overlay")
                        val semOverlay = call.argument<Boolean>("semOverlay") ?: false
                        val modoVenc = call.argument<Boolean>("vencimentos") ?: false
                        val misto = call.argument<Boolean>("misto") ?: false
                        val comums = call.argument<List<Int>>("comums") ?: emptyList()
                        val topFracs = call.argument<List<Double>>("topFracs") ?: emptyList()
                        val validades = call.argument<List<String>>("validades") ?: emptyList()
                        val shiftVenc = (call.argument<Double>("shiftVenc") ?: 0.015).toFloat()
                        val shiftMulti = (call.argument<Double>("shiftMulti") ?: 0.03).toFloat()
                        val format = call.argument<String>("format") ?: "png"
                        val maxDim = call.argument<Int>("maxDim") ?: 0
                        if (pdfs.isEmpty() || cols <= 0 || rows <= 0 || cellW <= 0 || cellH <= 0) {
                            result.error("BAD_ARGS", "pdfs/cols/rows/cellW/cellH invalid", null)
                            return@setMethodCallHandler
                        }
                        // Trabalho pesado FORA da main thread (como as
                        // coroutines do MLoja): rodar aqui travava a UI por
                        // vários segundos e qualquer toque gerava ANR/crash.
                        // Captura Throwable (inclui OOM) — Dart faz fallback.
                        Thread {
                            try {
                                val page = composePageFromPdfs(
                                    pdfs, cols, rows, cellW, cellH,
                                    overlayName, semOverlay, modoVenc, misto,
                                    comums, topFracs, validades,
                                    shiftVenc, shiftMulti, format, maxDim
                                )
                                runOnUiThread {
                                    try {
                                        result.success(page)
                                    } catch (_: Throwable) {
                                    }
                                }
                            } catch (t: Throwable) {
                                runOnUiThread {
                                    try {
                                        result.error("EXC", t.message, null)
                                    } catch (_: Throwable) {
                                    }
                                }
                            }
                        }.start()
                    }
                    "compartilharPdf" -> {
                        @Suppress("UNCHECKED_CAST")
                        val pdfsRaw2 = call.argument<List<Any>>("pdfs")
                        val pdfs2 = pdfsRaw2?.mapNotNull { it as? ByteArray } ?: emptyList()
                        val cols2 = call.argument<Int>("cols") ?: 1
                        val rows2 = call.argument<Int>("rows") ?: 1
                        val cellW2 = call.argument<Int>("cellW") ?: 0
                        val cellH2 = call.argument<Int>("cellH") ?: 0
                        val overlayName2 = call.argument<String>("overlay")
                        val semOverlay2 = call.argument<Boolean>("semOverlay") ?: false
                        val modoVenc2 = call.argument<Boolean>("vencimentos") ?: false
                        val misto2 = call.argument<Boolean>("misto") ?: false
                        val comums2 = call.argument<List<Int>>("comums") ?: emptyList()
                        val topFracs2 = call.argument<List<Double>>("topFracs") ?: emptyList()
                        val validades2 = call.argument<List<String>>("validades") ?: emptyList()
                        val shiftVenc2 = (call.argument<Double>("shiftVenc") ?: 0.015).toFloat()
                        val shiftMulti2 = (call.argument<Double>("shiftMulti") ?: 0.03).toFloat()
                        val isLandscape2 = call.argument<Boolean>("isLandscape") ?: false
                        if (pdfs2.isEmpty() || cols2 <= 0 || rows2 <= 0 || cellW2 <= 0 || cellH2 <= 0) {
                            result.error("BAD_ARGS", "pdfs/cols/rows/cellW/cellH invalid", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val scalePdf = 2
                                val composed = composePageFromPdfs(
                                    pdfs2, cols2, rows2, cellW2 * scalePdf, cellH2 * scalePdf,
                                    overlayName2, semOverlay2, modoVenc2, misto2,
                                    comums2, topFracs2, validades2,
                                    shiftVenc2, shiftMulti2, "png", 0
                                )
                                val path = composed["path"] as? String
                                val pageW = composed["width"] as? Int ?: 0
                                val pageH = composed["height"] as? Int ?: 0
                                if (path == null || pageW <= 0 || pageH <= 0) {
                                    runOnUiThread { result.error("PDF_FAIL", "compose failed", null) }
                                    return@Thread
                                }
                                val composedBmp = BitmapFactory.decodeFile(path)
                                File(path).delete()
                                if (composedBmp == null) {
                                    runOnUiThread { result.error("PDF_FAIL", "decode failed", null) }
                                    return@Thread
                                }
                                val a4W = 595; val a4H = 842
                                val MARGIN = 14f
                                val pdfPageW = if (isLandscape2) a4H else a4W
                                val pdfPageH = if (isLandscape2) a4W else a4H
                                val pdfDoc = android.graphics.pdf.PdfDocument()
                                val pageInfo = android.graphics.pdf.PdfDocument.PageInfo.Builder(
                                    pdfPageW, pdfPageH, 1
                                ).create()
                                val pdfPage = pdfDoc.startPage(pageInfo)
                                val canvas = pdfPage.canvas
                                canvas.drawColor(Color.WHITE)
                                val dst = RectF(MARGIN, MARGIN, pdfPageW - MARGIN, pdfPageH - MARGIN)
                                val bmpPaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
                                canvas.drawBitmap(composedBmp, null, dst, bmpPaint)
                                pdfDoc.finishPage(pdfPage)
                                composedBmp.recycle()
                                val pdfFile = File(cacheDir, "papeletas_${System.nanoTime()}.pdf")
                                FileOutputStream(pdfFile).use { pdfDoc.writeTo(it) }
                                pdfDoc.close()
                                val uri = androidx.core.content.FileProvider.getUriForFile(
                                    this@MainActivity, "${packageName}.fileprovider", pdfFile)
                                val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                                    type = "application/pdf"
                                    putExtra(android.content.Intent.EXTRA_STREAM, uri)
                                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                runOnUiThread {
                                    try {
                                        startActivity(android.content.Intent.createChooser(intent, "Compartilhar PDF com"))
                                        result.success(null)
                                    } catch (e: Exception) {
                                        result.error("SHARE_FAIL", e.message, null)
                                    }
                                }
                            } catch (t: Throwable) {
                                runOnUiThread { result.error("EXC", t.message, null) }
                            }
                        }.start()
                    }
                    "saveToDownloadsAndOpen" -> {
                        val fileName = call.argument<String>("fileName") ?: "arquivo.pdf"
                        val bytes = call.argument<ByteArray>("bytes")
                        val mime = call.argument<String>("mime") ?: "application/pdf"
                        if (bytes == null) {
                            result.error("BAD_ARGS", "bytes null", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                var savedUri: android.net.Uri? = null
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                                    val values = android.content.ContentValues().apply {
                                        put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                                        put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mime)
                                        put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, android.os.Environment.DIRECTORY_DOWNLOADS)
                                    }
                                    val uri = contentResolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                        ?: throw IllegalStateException("MediaStore insert failed")
                                    contentResolver.openOutputStream(uri)?.use { out ->
                                        out.write(bytes)
                                    } ?: throw IllegalStateException("MediaStore write failed")
                                    savedUri = uri
                                } else {
                                    @Suppress("DEPRECATION")
                                    val dl = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
                                    if (!dl.exists()) dl.mkdirs()
                                    val f = File(dl, fileName)
                                    f.writeBytes(bytes)
                                    savedUri = androidx.core.content.FileProvider.getUriForFile(
                                        this@MainActivity, "${packageName}.fileprovider", f)
                                }
                                if (savedUri != null) {
                                    val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                                        setDataAndType(savedUri, mime)
                                        addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    runOnUiThread {
                                        try {
                                            startActivity(intent)
                                            result.success(null)
                                        } catch (e: Exception) {
                                            result.error("OPEN_FAIL", e.message, null)
                                        }
                                    }
                                } else {
                                    runOnUiThread { result.error("SAVE_FAIL", "uri null", null) }
                                }
                            } catch (t: Throwable) {
                                runOnUiThread { result.error("EXC", t.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Breadcrumb nativo com flush imediato (diagnóstico de crash seco). */
    private fun bstep(msg: String) {
        try {
            val dir = getExternalFilesDir(null) ?: filesDir
            File(dir, "passos_native.txt")
                .appendText("[${System.currentTimeMillis()}] $msg\n")
        } catch (_: Throwable) {
        }
    }

    private fun assetBytes(name: String): ByteArray? = try {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(name)
        assets.open(key).use { it.readBytes() }
    } catch (_: Exception) {
        null
    }

    /**
     * Compõe a página inteira nativamente a partir dos PDFs da API (payload
     * pequeno — sem pixels atravessando o canal): renderiza cada célula via
     * PdfRenderer, aplica removerBrancoSuave + centralizarConteudo e, no
     * Vencimentos, desenha validade/rodapé. Grava o PNG em cacheDir e devolve
     * {"path": ...} — resposta minúscula pelo canal.
     */
    private fun composePageFromPdfs(
        pdfs: List<ByteArray>,
        cols: Int,
        rows: Int,
        cellW: Int,
        cellH: Int,
        overlayName: String?,
        semOverlay: Boolean,
        modoVenc: Boolean,
        misto: Boolean,
        comums: List<Int>,
        topFracs: List<Double>,
        validades: List<String>,
        shiftVenc: Float,
        shiftMulti: Float,
        format: String,
        maxDim: Int
    ): Map<String, Any> {
        val ovW = cellW * cols
        val ovH = cellH * rows
        bstep("compose start n=${pdfs.size} ${ovW}x$ovH fmt=$format")

        val page = Bitmap.createBitmap(ovW, ovH, Bitmap.Config.ARGB_8888)
        bstep("bitmap pagina criado")
        val cv = Canvas(page)
        cv.drawColor(Color.WHITE)

        // Sempre overlay 1x1 por célula (tiling), todos os modos.
        var overlay: Bitmap? = null
        if (!semOverlay && overlayName != null) {
            val ob = assetBytes(overlayName)
            if (ob != null) overlay = BitmapFactory.decodeByteArray(ob, 0, ob.size)
        }

        val whitePaint = Paint().apply { color = Color.WHITE }

        for (i in pdfs.indices) {
            bstep("celula $i render inicio")
            val bmp = renderPdfToBitmap(pdfs[i], cellW, cellH, maxScale = 6) ?: continue
            removerBrancoSuave(bmp)
            bstep("celula $i ok ${bmp.width}x${bmp.height}")

            val left = (i % cols) * cellW.toFloat()
            val top = (i / cols) * cellH.toFloat()
            val comum = comums.getOrNull(i) == 1

            if (overlay != null) {
                if (comum) {
                    cv.drawRect(left, top, left + cellW, top + cellH, whitePaint)
                } else {
                    val src = Rect(0, 0, overlay.width, overlay.height)
                    val dst = RectF(left, top, left + cellW, top + cellH)
                    cv.drawBitmap(overlay, src, dst, null)
                }
            }
            // Fiel ao MLoja: escala o bitmap renderizado para o tamanho exato da
            // célula ANTES de centralizar — bilinear filter garante nitidez.
            val scaled = Bitmap.createScaledBitmap(bmp, cellW, cellH, true)
            if (scaled !== bmp) bmp.recycle()
            val maxShift = if (modoVenc && !comum) 0.35f else 1f
            val ignorar = if (comum) 0.03f else 0f
            val shiftY = if (comum) 0f else (if (modoVenc) shiftVenc else shiftMulti)
            centralizarConteudo(cv, scaled, cellW.toFloat(), cellH.toFloat(), left, top, maxShift, ignorar, shiftY)

            val vd = validades.getOrNull(i)?.trim() ?: ""
            if (modoVenc && vd.isNotEmpty()) {
                val tf = (topFracs.getOrNull(i) ?: 0.25).toFloat()
                desenharTextosVenc(cv, left, top, cellW.toFloat(), cellH.toFloat(), vd, tf)
            }
            scaled.recycle()
        }
        overlay?.recycle()

        // Preview: reduz a página para tamanho de exibição ANTES de codificar —
        // texturas pequenas não estouram a GPU ao deslizar/zoom.
        var outBmp = page
        if (maxDim > 0 && (ovW > maxDim || ovH > maxDim)) {
            val s = min(maxDim.toFloat() / ovW, maxDim.toFloat() / ovH)
            val nw = (ovW * s).toInt().coerceAtLeast(1)
            val nh = (ovH * s).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(page, nw, nh, true)
            if (scaled !== page) {
                page.recycle()
                outBmp = scaled
            }
            bstep("downscale $ovW x $ovH -> $nw x $nh")
        }

        // JPEG (preview) codifica ~3x mais rápido que PNG; a página composta
        // é opaca, então não há perda de transparência. Impressão/PDF usa PNG.
        val isJpeg = format.equals("jpeg", ignoreCase = true)
        val out = File(cacheDir, "page_${System.nanoTime()}.${if (isJpeg) "jpg" else "png"}")
        bstep("encode inicio")
        FileOutputStream(out).use {
            if (isJpeg) outBmp.compress(Bitmap.CompressFormat.JPEG, 92, it)
            else outBmp.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
        bstep("encode ok")
        val res =
            mapOf<String, Any>("path" to out.absolutePath, "width" to outBmp.width, "height" to outBmp.height)
        outBmp.recycle()
        return res
    }

    /** Renderiza a 1a página do PDF num bitmap na proporção nativa (~alvo). */
    private fun renderPdfToBitmap(bytes: ByteArray, targetW: Int, targetH: Int, maxScale: Int = 8): Bitmap? {
        val file = File(cacheDir, "pdf_cell_${System.nanoTime()}.pdf")
        file.outputStream().use { it.write(bytes) }
        val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(fd)
        try {
            if (renderer.pageCount < 1) return null
            renderer.openPage(0).use { page ->
                val pw = page.width.toDouble()
                val ph = page.height.toDouble()
                val s1 = ceil(targetW / pw)
                val s2 = ceil(targetH / ph)
                var scaleD = if (s1 < s2) s1 else s2
                if (scaleD > maxScale.toDouble()) scaleD = maxScale.toDouble()
                if (scaleD < 1.0) scaleD = 1.0
                val sInt = scaleD.toInt()
                val rw = (pw * sInt).toInt().coerceAtMost(10000)
                val rh = (ph * rw / pw).toInt()
                val bmp = Bitmap.createBitmap(rw, rh, Bitmap.Config.ARGB_8888)
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                return bmp
            }
        } finally {
            renderer.close()
            fd.close()
            file.delete()
        }
    }

    /** Igual ao centralizarConteudo do MLoja: estica na célula, só dx. */
    private fun centralizarConteudo(
        canvas: Canvas, bmp: Bitmap, cellW: Float, cellH: Float,
        left: Float, top: Float, maxShiftFrac: Float,
        ignorarBordasFrac: Float, shiftYFrac: Float
    ) {
        try {
            val w = bmp.width; val h = bmp.height
            val targetW = min(w, 1200)
            val targetH = ((h * (targetW.toFloat() / w)).toInt()).coerceAtLeast(1)
            val small = if (targetW < w) Bitmap.createScaledBitmap(bmp, targetW, targetH, true) else bmp
            val sw = small.width; val sh = small.height
            val bx0 = (sw * ignorarBordasFrac).toInt()
            val bx1 = (sw * (1f - ignorarBordasFrac)).toInt()
            val by0 = (sh * ignorarBordasFrac).toInt()
            val by1 = (sh * (1f - ignorarBordasFrac)).toInt()
            var minX = sw; var maxX = -1
            var y = by0
            while (y < by1) {
                var x = bx0
                while (x < bx1) {
                    val p = small.getPixel(x, y)
                    if ((p ushr 24 and 0xFF) > 8) {
                        val r = p shr 16 and 0xFF; val g = p shr 8 and 0xFF; val b = p and 0xFF
                        if (r < 250 || g < 250 || b < 250) {
                            if (x < minX) minX = x
                            if (x > maxX) maxX = x
                        }
                    }
                    x += 4
                }
                y += 4
            }
            val dstTop = top - cellH * shiftYFrac
            if (maxX <= minX) {
                canvas.drawBitmap(bmp, null, RectF(left, dstTop, left + cellW, dstTop + cellH), null)
                if (small !== bmp) small.recycle()
                return
            }
            val scaleX = cellW / sw
            val contentDrawW = (maxX - minX + 1) * scaleX
            val dx = (((cellW - contentDrawW) / 2f) - minX * scaleX)
                .coerceIn(-cellW * maxShiftFrac, cellW * maxShiftFrac)
            canvas.drawBitmap(bmp, null, RectF(left + dx, dstTop, left + dx + cellW, dstTop + cellH), null)
            if (small !== bmp) small.recycle()
        } catch (_: Exception) {
            canvas.drawBitmap(
                bmp, null,
                RectF(left, top - cellH * shiftYFrac, left + cellW, top + cellH - cellH * shiftYFrac),
                null
            )
        }
    }

    /** Torna o branco suave transparente (removeBrancoSuave do MLoja). */
    private fun removerBrancoSuave(src: Bitmap) {
        val w = src.width; val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)
        for (i in px.indices) {
            val p = px[i]
            val a = p ushr 24 and 0xFF
            if (a < 200) continue
            val r = p shr 16 and 0xFF; val g = p shr 8 and 0xFF; val b = p and 0xFF
            val minRGB = min(r, min(g, b))
            if (minRGB >= 200) {
                val t = ((minRGB - 200) / 55f).coerceIn(0f, 1f)
                val newA = ((a * (1 - t * 0.95f)).roundToInt()).coerceIn(0, 255)
                px[i] = if (newA < 4) (p and 0x00FFFFFF) else (newA shl 24) or (p and 0x00FFFFFF)
            }
        }
        src.setPixels(px, 0, w, 0, 0, w, h)
    }

    /** VAL.: <data> + rodapé, vermelho negrito, centrados na célula. */
    private fun desenharTextosVenc(
        canvas: Canvas, left: Float, top: Float, cellW: Float,
        cellH: Float, validade: String, topFrac: Float
    ) {
        val txt = if (validade.length == 8) {
            "${validade.substring(0, 2)}/${validade.substring(2, 4)}/${validade.substring(4)}"
        } else validade

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#D32F2F")
            typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }

        fun draw(s: String, cy: Float, sizePx: Float) {
            paint.textSize = sizePx
            val fm = paint.fontMetrics
            val baseline = cy - (fm.ascent + fm.descent) / 2f
            canvas.drawText(s, left + cellW / 2f, baseline, paint)
        }

        draw("VAL.: ${txt.uppercase()}", top + cellH * topFrac, cellW / 18f)
        draw("PRÓXIMO DA VALIDADE. CONSUMO RÁPIDO", top + cellH * 0.88f, (cellW / 32f).coerceIn(8f, 26f))
    }

    // Fiel ao renderPdfToBitmap do MLoja: renderiza a página em sua proporção
    // nativa via PdfRenderer (RENDER_MODE_FOR_PRINT).
    private fun renderPdfToRgba(bytes: ByteArray, targetW: Int, targetH: Int): Map<String, Any>? {
        val file = File(cacheDir, "pdf_render_${System.currentTimeMillis()}.pdf")
        file.outputStream().use { it.write(bytes) }
        val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(fd)
        try {
            if (renderer.pageCount < 1) return null
            renderer.openPage(0).use { page ->
                val pw = page.width.toDouble()
                val ph = page.height.toDouble()
                val s1 = ceil(targetW / pw)
                val s2 = ceil(targetH / ph)
                var scaleD = if (s1 < s2) s1 else s2
                if (scaleD > 8.0) scaleD = 8.0
                if (scaleD < 1.0) scaleD = 1.0
                val sInt = scaleD.toInt()
                val rw = (pw * sInt).toInt().coerceAtMost(10000)
                val rh = (ph * rw / pw).toInt()
                val bmp = Bitmap.createBitmap(rw, rh, Bitmap.Config.ARGB_8888)
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                val stream = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.PNG, 100, stream)
                bmp.recycle()
                return mapOf("width" to rw, "height" to rh, "bytes" to stream.toByteArray())
            }
        } finally {
            renderer.close()
            fd.close()
            file.delete()
        }
    }
}
