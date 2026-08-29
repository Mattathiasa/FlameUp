# FlameUp R8 rules.
#
# Only what shrinking actually breaks. A blanket -keep would defeat the point
# of minifying at all.

# Flutter's embedding is reached reflectively by the engine.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase models are deserialised by field name, so their members must keep
# their names or every document read comes back empty.
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class com.google.firebase.** { *; }
-keep class com.google.firebase.** { *; }

# Sign-in providers.
-keep class com.google.android.gms.auth.** { *; }

# flutter_local_notifications schedules through reflection, and its receivers
# are named in the manifest rather than referenced in code.
-keep class com.dexterous.** { *; }

# Crashlytics needs line numbers and source files to symbolicate a report;
# without these a release crash is close to unreadable.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# R8 warns about optional desugaring classes that are never reached at runtime.
-dontwarn java.lang.invoke.**
-dontwarn **$$serializer

# Flutter's deferred-components support references Play Core, which this app
# does not use and does not depend on. R8 fails the build on the dangling
# references unless they are explicitly allowed to be absent.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
