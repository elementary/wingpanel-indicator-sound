/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

[DBus (name = "io.elementary.wingpanel.sound")]
public class Sound.DBus : GLib.Object {
    [DBus (visible = false)]
    public signal void on_handle_osd ();

    private static GLib.Once<Sound.DBus> instance;

    [DBus (visible = false)]
    public static Sound.DBus get_default () {
        return instance.once (() => {
            return new Sound.DBus ();
        });
    }

    private DBus () {
        Object ();
    }

    [DBus (visible = false)]
    public static void init () {
        Bus.own_name (SESSION, "io.elementary.wingpanel.sound", NONE,
            (connection) => {
                try {
                    connection.register_object ("/io/elementary/wingpanel/sound", get_default ());
                } catch (Error e) {
                    warning (e.message);
                }
            },
            () => {},
            () => warning ("Could not acquire name")
        );
    }

    public void handle_osd () throws DBusError, IOError {
        on_handle_osd ();
    }
}
