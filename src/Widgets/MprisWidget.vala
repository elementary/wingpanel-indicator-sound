/*
 * Copyright (c) 2014 Ikey Doherty <ikey.doherty@gmail.com>
 *               2015-2017 elementary LLC. (http://launchpad.net/wingpanel)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Sound.Widgets.MprisWidget : Gtk.Box {
    Services.DBusImpl impl;

    AppInfo? default_music;
    ClientWidget default_widget;
    HashTable<string,ClientWidget> ifaces;
    public signal void close ();

    public MprisWidget() {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 1);

        ifaces = new HashTable<string,ClientWidget>(str_hash, str_equal);

        Idle.add(()=> {
            setup_dbus();
            return false;
        });

        default_music = AppInfo.get_default_for_type ("audio/x-vorbis+ogg", false);
        if (default_music != null) {
            default_widget = new ClientWidget.default (default_music);

            default_widget.close.connect (() => {
                close ();
            });

            default_widget.show_all();
            pack_start(default_widget, false, false, 0);
        }

        show_all();
    }

    public void pause_all () {
        foreach (var cw in ifaces.get_values ()) {
            try {
                cw.client.player.pause ();
            } catch  (Error e) {
                warning ("Could not pause: %s", e.message);
            }
        }
    }

    /**
     * Add an interface handler/widget to known list and UI
     *
     * @param name DBUS name (object path)
     * @param iface The constructed MprisClient instance
     */
    void add_iface (string name, Services.MprisClient iface) {
        if (iface.player.desktop_entry == default_music.get_id ().replace (".desktop","")) {
            default_widget.mpris_name = name;
            default_widget.client = iface;
            ifaces.insert(name, default_widget);
            default_widget.no_show_all = false;
            default_widget.visible = true;
        } else {
            if (default_widget.mpris_name == "") {
                default_widget.no_show_all = true;
                default_widget.visible = false;
            }

            ClientWidget widg = new ClientWidget (iface);
            widg.close.connect (() => {
                close ();
            });
            widg.show_all();
            pack_start(widg, false, false, 0);
            ifaces.insert(name, widg);
        }
    }

    /**
     * Destroy an interface handler and remove from UI
     *
     * @param name DBUS name to remove handler for
     */
    void destroy_iface(string name) {
        if (default_widget.mpris_name == name) {
            default_widget.client = null;
        } else {
            var widg = ifaces[name];
            if (widg  != null) {
                remove(widg);
            }
        }

        ifaces.remove(name);

        if (ifaces.length != 0 && default_widget.mpris_name == "") {
            default_widget.no_show_all = true;
            default_widget.visible = false;
        } else {
            default_widget.no_show_all = false;
            default_widget.visible = true;
            show_all ();
        }
    }

    /**
     * Do basic dbus initialisation
     */
    public void setup_dbus() {
        try {
            impl = Bus.get_proxy_sync(BusType.SESSION, "org.freedesktop.DBus", "/org/freedesktop/DBus");
            var names = impl.list_names();

            /* Search for existing players (launched prior to our start) */
            foreach (var name in names) {
                if (name.has_prefix("org.mpris.MediaPlayer2.")) {
                    bool add = true;
                    foreach (string name2 in ifaces.get_keys ()) {
                        // skip if already a interface is present.
                        // some version of vlc register two
                        if (name2.has_prefix (name) || name.has_prefix (name2)) {
                            add = false;
                        }
                    }
                    if (add) {
                        var iface = new_iface(name);
                        if (iface != null) {
                            add_iface(name, iface);
                        }
                    }
                }
            }

            /* Also check for new mpris clients coming up while we're up */
            impl.name_owner_changed.connect((n,o,ne)=> {
                /* Separate.. */
                if (n.has_prefix("org.mpris.MediaPlayer2.")) {
                    if (o == "") {
                        // delay the sync because otherwise the dbus properties are not yet intialized!
                        Timeout.add (100, () => {
                            foreach (string name in ifaces.get_keys ()) {
                                // skip if already a interface is present.
                                // some version of vlc register two
                                if (name.has_prefix (n) || n.has_prefix (name)) {
                                    return false;
                                }
                            }
                            var iface = new_iface(n);
                            if (iface != null) {
                                add_iface(n,iface);
                            }
                            return false;
                        });
                    } else {
                        Idle.add(()=> {
                            destroy_iface(n);
                            return false;
                        });
                    }
                }
            });
        } catch (Error e) {
            warning("Failed to initialise dbus: %s", e.message);
        }
    }

    /**
     * Utility function, return a new iface instance, i.e. deal
     * with all the dbus cruft
     *
     * @param busname The busname to instaniate ifaces from
     * @return a new MprisClient, or null if errors occurred.
     */
    public Services.MprisClient? new_iface(string busname) {
        Services.PlayerIface? play = null;
        Services.MprisClient? cl = null;
        Services.DbusPropIface? prop = null;

        try {
            play = Bus.get_proxy_sync(BusType.SESSION, busname, "/org/mpris/MediaPlayer2");
        } catch (Error e) {
            message(e.message);
            return null;
        }
        try {
            prop = Bus.get_proxy_sync(BusType.SESSION, busname, "/org/mpris/MediaPlayer2");
        } catch (Error e) {
            message(e.message);
            return null;
        }
        cl = new Services.MprisClient(play, prop);

        return cl;
    }
}
