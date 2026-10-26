# Flutter Engine & Plugins
-keep class io.flutter.** { *; }
-keep class com.antigravity.home.unified_home.** { *; }

# Preserve all JNI native methods across libraries
-keepclasseswithmembernames class * {
    native <methods>;
}

# MediaKit / MPV video player & JNI bindings
-keep class com.alexmercerind.media_kit.** { *; }
-keep class com.alexmercerind.media_kit_video.** { *; }
-dontwarn com.alexmercerind.media_kit.**

# WebView Javascript interfaces
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# General Keep Attributes
-keepattributes *Annotation*
-keepclassmembers enum * { *; }
