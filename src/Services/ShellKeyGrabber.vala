/**
 * ActionMode:
 * @NONE: block action
 * @NORMAL: allow action when in window mode, e.g. when the focus is in an application window
 * @OVERVIEW: allow action while the overview is active
 * @LOCK_SCREEN: allow action when the screen is locked, e.g. when the screen shield is shown
 * @UNLOCK_SCREEN: allow action in the unlock dialog
 * @LOGIN_SCREEN: allow action in the login screen
 * @SYSTEM_MODAL: allow action when a system modal dialog (e.g. authentification or session dialogs) is open
 * @LOOKING_GLASS: allow action in looking glass
 * @POPUP: allow action while a shell menu is open
 */
[Flags]
public enum ActionMode {
    NONE = 0,
    NORMAL = 1 << 0,
    OVERVIEW = 1 << 1,
    LOCK_SCREEN = 1 << 2,
    UNLOCK_SCREEN = 1 << 3,
    LOGIN_SCREEN = 1 << 4,
    SYSTEM_MODAL = 1 << 5,
    LOOKING_GLASS = 1 << 6,
    POPUP = 1 << 7,
}

[Flags]
public enum Meta.KeyBindingFlags {
    NONE = 0,
    PER_WINDOW = 1 << 0,
    BUILTIN = 1 << 1,
    IS_REVERSED = 1 << 2,
    NON_MASKABLE = 1 << 3,
    IGNORE_AUTOREPEAT = 1 << 4,
}

public struct Accelerator {
    public string name;
    public ActionMode mode_flags;
    public Meta.KeyBindingFlags grab_flags;
}

[DBus (name = "org.gnome.Shell")]
public interface ShellKeyGrabber : GLib.Object {
    public abstract signal void accelerator_activated (uint action, GLib.HashTable<string, GLib.Variant> parameters_dict);

    public abstract uint grab_accelerator (string accelerator, ActionMode mode_flags, Meta.KeyBindingFlags grab_flags) throws GLib.DBusError, GLib.IOError;
    public abstract uint[] grab_accelerators (Accelerator[] accelerators) throws GLib.DBusError, GLib.IOError;
    public abstract bool ungrab_accelerator (uint action) throws GLib.DBusError, GLib.IOError;
    public abstract bool ungrab_accelerators (uint[] actions) throws GLib.DBusError, GLib.IOError;
    [DBus (name = "ShowOSD")]
    public abstract void show_osd (GLib.HashTable<string, GLib.Variant> parameters_dict) throws GLib.DBusError, GLib.IOError;
}
