# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase rules
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }

# Keep Supabase generated classes
-keep class io.supabase.goTrue.** { *; }
-keep class io.supabase.realtime.** { *; }
-keep class io.supabase.storage.** { *; }

# Keep model classes
-keep class com.markspencer.ez2lotto.** { *; }

# Prevent obfuscation of classes which use @JsonSerializable
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Preserve line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Google Play Core (optional Flutter dependency)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
