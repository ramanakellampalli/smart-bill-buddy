# Preserve generic type signatures — required by Gson TypeToken
# (used by flutter_local_notifications to load scheduled notifications)
-keepattributes Signature
-keepattributes *Annotation*

# Gson
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Flutter local notifications
-keep class com.dexterous.** { *; }
