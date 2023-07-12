/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[DBus (name = "io.elementary.wingpanel.sound")]
public class Sound.DBus : GLib.Object {
    private static DBus? instance;
    private static Indicator indicator;

    [DBus (visible = false)]
    public static void init (Indicator _indicator) {
        indicator = _indicator;

        Bus.own_name (SESSION, "io.elementary.wingpanel.sound", NONE,
            (connection) => {
                if (instance == null) {
                    instance = new DBus ();
                }

                try {
                    connection.register_object ("/io/elementary/wingpanel/sound", instance);
                } catch (Error e) {
                    warning (e.message);
                }
            },
            () => {},
            () => warning ("Could not acquire name")
        );
    }

    public void volume_up () throws DBusError, IOError {
        indicator.handle_change (1.0, false);
    }

    public void volume_down () throws DBusError, IOError {
        indicator.handle_change (-1.0, false);
    }

    public void mute () throws DBusError, IOError {
        indicator.dbus_handle_mute ();
    }
}