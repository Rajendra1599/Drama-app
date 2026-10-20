# Flutter Wrapper & Engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# AndroidX WorkManager & Room (Fixes: Failed to create an instance of androidx.work.impl.WorkDatabase)
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.room.** { *; }
-keep class androidx.startup.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# Google Mobile Ads SDK
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }
-dontwarn com.google.android.gms.auth.api.signin.**
