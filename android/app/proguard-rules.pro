# PdfBox-Android (merge vetorial) — R8
-keep class com.tom_roush.pdfbox.** { *; }
-dontwarn com.tom_roush.pdfbox.**
# Dependências opcionais do PdfBox (JPEG2000/bouncycastle) que não usamos
-dontwarn com.gemalto.jp2.**
-dontwarn org.bouncycastle.**
-dontwarn javax.**
