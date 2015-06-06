/*
 * MprisWidget.vala
 *
 * Copyright
 * 2014 Ikey Doherty <ikey.doherty@gmail.com>
 * 2015 Wingpanel Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

public class Sound.Widgets.MprisWidget : Gtk.Box
{
    Services.DBusImpl impl;

    HashTable<string,ClientWidget> ifaces;
    public signal void child_count_changed (int count);
    public signal void close ();

    public MprisWidget() {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 1);

        ifaces = new HashTable<string,ClientWidget>(str_hash, str_equal);

        Idle.add(()=> {
            setup_dbus();
            return false;
        });

        show_all();
    }

    /**
     * Add an interface handler/widget to known list and UI
     *
     * @param name DBUS name (object path)
     * @param iface The constructed MprisClient instance
     */
    void add_iface(string name, Services.MprisClient iface) {
        ClientWidget widg = new ClientWidget(iface);
        widg.close.connect (() => {
            close ();
        });
        widg.show_all();
        pack_start(widg, false, false, 0);
        ifaces.insert(name, widg);
        child_count_changed ((int) ifaces.length);
    }

    /**
     * Destroy an interface handler and remove from UI
     *
     * @param name DBUS name to remove handler for
     */
    void destroy_iface(string name) {
        var widg = ifaces[name];
        if (widg  != null) {
            remove(widg);
            ifaces.remove(name);
            child_count_changed ((int) ifaces.length);
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
                        if (name2.has_prefix (name) || name.has_prefix (name2))
                            add = false;
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
                                if (name.has_prefix (n) || n.has_prefix (name))
                                    return false;
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