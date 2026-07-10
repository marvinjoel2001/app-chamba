# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Zego (llamadas y push ZPNs) + Gson
# R8 en modo full borra las firmas genéricas de las subclases de TypeToken,
# lo que crashea ZPNsFCMReceiver al llegar una notificación en release:
# "TypeToken must be created with a type argument"
-keep class im.zego.** { *; }
-dontwarn im.zego.**
-keep class **.zego.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep MainActivity
-keep class com.example.mobile.MainActivity { *; }

# Prevent R8 from stripping interface info for serialized classes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Don't warn about missing classes from dependencies
-dontwarn com.google.**
-dontwarn io.flutter.**
