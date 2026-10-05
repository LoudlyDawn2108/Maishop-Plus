# ML Kit Text Recognition Proguard / R8 rules
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**

-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
