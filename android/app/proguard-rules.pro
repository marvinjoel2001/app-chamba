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
