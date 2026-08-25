# ECHO//LINE ProGuard Rules

# Keep Godot classes
-keep class com.godot.game.** { *; }
-keep class com.godot.game.GodotApp { *; }

# Keep Godot's reflection-friendly types
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep signal-based methods
-keepclassmembers class * extends com.godot.game.GodotLib {
    @com.godot.game.Signal <methods>;
}
-keepclassmembers class * {
    @com.godot.game.Signal <methods>;
}

# Keep all autoloads (registered in project.godot)
-keep class **.accessibility_service { *; }
-keep class **.audio_mixer_service { *; }
-keep class **.network_client { *; }
-keep class **.dark_patterns_guard { *; }
-keep class **.ux_telemetry { *; }
-keep class **.localization { *; }
-keep class **.event_bus { *; }
-keep class **.iap_manager { *; }
-keep class **.audio_manager { *; }
-keep class **.haptics_manager { *; }
-keep class **.graphics_manager { *; }

# Keep all gameplay scripts
-keep class **.player_controller { *; }
-keep class **.npc_controller { *; }
-keep class **.bot_controller { *; }
-keep class **.interactive_prop { *; }
-keep class **.achievement_system { *; }
-keep class **.quest_system { *; }

# Keep UI components
-keep class **.hud { *; }
-keep class **.lobby_view { *; }
-keep class **.quick_chat_safe { *; }
-keep class **.safe_confirm_dialog { *; }
-keep class **.connection_state_indicator { *; }
-keep class **.touch_target_validator { *; }
-keep class **.virtual_joystick { *; }
-keep class **.causal_recap_view { *; }

# Keep building system
-keep class **.shard_inventory { *; }
-keep class **.anchor_placement_controller { *; }
-keep class **.anchor_network_sync { *; }
-keep class **.snap_grid { *; }
-keep class **.shard_inventory_bar { *; }
-keep class **.shard_slot_button { *; }
-keep class **.anchor_blueprint_panel { *; }

# Keep Godot native (jni)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Don't strip native method names
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep enums (Godot uses int constants)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Strip Android log calls in release (optional)
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}

# Keep crash reporting
-keep class **.crash_handler { *; }

# Don't warn on missing classes from Google Play Services
-dontwarn com.google.android.gms.**
-dontwarn com.google.errorprone.annotations.**

# Don't warn on AndroidX dependencies
-dontwarn androidx.**

# Don't warn on Godot internal classes
-dontwarn com.godot.**

# Keep our app package
-keep class com.echoline.game.** { *; }