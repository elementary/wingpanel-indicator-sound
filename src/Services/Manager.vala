/*
 * Copyright (c) 2015-2017 elementary LLC. (http://launchpad.net/wingpanel-indicator-sound)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; If not, see <http://www.gnu.org/licenses/>.
 *
 */

[DBus (name = "org.freedesktop.DBus.ObjectManager")]
public interface Sound.Services.DBusInterface : Object {
    public signal void interfaces_added (ObjectPath object_path, HashTable<string, HashTable<string, Variant>> param);
    public signal void interfaces_removed (ObjectPath object_path, string[] string_array);

    public abstract HashTable<ObjectPath, HashTable<string, HashTable<string, Variant>>> get_managed_objects () throws GLib.Error;
}

public class Sound.Services.ObjectManager : Object {
    public signal void global_state_changed (bool enabled, bool connected);
    public signal void adapter_added (Services.Adapter adapter);
    public signal void adapter_removed (Services.Adapter adapter);
    public signal void device_added (Services.Device adapter);
    public signal void device_removed (Services.Device adapter);
    public signal void media_player_added (Services.MediaPlayer media_player, string name, string icon);
    public signal void media_player_removed (Services.MediaPlayer media_player);
    public signal void media_player_status_changed (string status, string title, string album);

    public bool has_object { get; private set; default = false; }
    public string media_player_status { get;  private set; default = "stopped";}
    public string current_track_title { get;  private set; default = "Not playing";}
    public string current_track_artist { get;  private set;}

    private Services.DBusInterface object_interface;
    private Gee.HashMap<string, Services.Adapter> adapters;
    private Gee.HashMap<string, Services.Device> devices;
    private Gee.HashMap<string, Services.MediaPlayer> media_players;

    public ObjectManager () { }

    construct {
        adapters = new Gee.HashMap<string, Services.Adapter> (null, null);
        devices = new Gee.HashMap<string, Services.Device> (null, null);
        media_players = new Gee.HashMap<string, Services.MediaPlayer> (null, null);

        Bus.get_proxy.begin<Services.DBusInterface> (BusType.SYSTEM, "org.bluez", "/", DBusProxyFlags.NONE, null, (obj, res) => {
            try {
                object_interface = Bus.get_proxy.end (res);
                object_interface.get_managed_objects ().foreach (add_path);
                object_interface.interfaces_added.connect (add_path);
                object_interface.interfaces_removed.connect (remove_path);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    [CCode (instance_pos = -1)]
    private void add_path (ObjectPath path, HashTable<string, HashTable<string, Variant>> param) {
        if ("org.bluez.Adapter1" in param) {
            try {
                Services.Adapter adapter = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                lock (adapters) {
                    adapters.set (path, adapter);
                }
                has_object = true;

                adapter_added (adapter);
                (adapter as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
                    var powered = changed.lookup_value ("Powered", new VariantType ("b"));
                    if (powered != null) {
                        check_global_state ();
                    }
                });
            } catch (Error e) {
                warning ("Connecting to bluetooth adapter failed: %s", e.message);
            }
        } else if ("org.bluez.Device1" in param) {
            try {
                Services.Device device = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                if (device.paired) {
                    lock (devices) {
                        devices.set (path, device);
                    }

                    device_added (device);
                }

                (device as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
                    var connected = changed.lookup_value ("Connected", new VariantType ("b"));
                    if (connected != null) {
                        check_global_state ();
                    }

                    var paired = changed.lookup_value ("Paired", new VariantType ("b"));
                    if (paired != null) {
                        if (device.paired) {
                            lock (devices) {
                                devices.set (path, device);
                            }

                            device_added (device);
                        } else {
                            lock (devices) {
                                devices.unset (path);
                            }

                            device_removed (device);
                        }
                    }
                });
            } catch (Error e) {
                warning ("Connecting to bluetooth device failed: %s", e.message);
            }
        } else if ("org.bluez.MediaPlayer1" in param) {
            try {           
                Services.MediaPlayer media_player = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", path, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                lock (media_players) {
                    media_players.set (path, media_player);
                }
                string device_name = path.substring (0, path.last_index_of("/"));
                Services.Device cur_device = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", device_name, DBusProxyFlags.GET_INVALIDATED_PROPERTIES);
                media_player_status = media_player.track.lookup ("Title").get_string (null);
                media_player_added (media_player, cur_device.name, cur_device.icon);

                (media_player as DBusProxy).g_properties_changed.connect ((changed, invalid) => {
                    if (changed.print (true).contains ("Track")) {
                        Variant tmp = changed.lookup_value ("Track", VariantType.DICTIONARY);
                        string title = tmp.lookup_value ("Title", VariantType.STRING).get_string (null);
                        string artist = tmp.lookup_value ("Artist", VariantType.STRING).get_string (null);
                        current_track_title = title;
                        current_track_artist = artist;
                        media_player_status_changed ("", title, artist);
                    } else if (changed.lookup("Status", "s")) {
                        string status = changed.lookup_value ("Status", VariantType.STRING).get_string (null);
                        media_player_status = status;
                        media_player_status_changed (status, "", "");
                    }
                });
            } catch (Error e) {
                warning ("Connecting to bluetooth media player failed: %s", e.message);
            }
        }
    }

    [CCode (instance_pos = -1)]
    public void remove_path (ObjectPath path) {
        lock (adapters) {
            var adapter = adapters.get (path);
            if (adapter != null) {
                adapters.unset (path);
                has_object = !adapters.is_empty;

                adapter_removed (adapter);
                return;
            }
        }

        lock (devices) {
            var device = devices.get (path);
            if (device != null) {
                devices.unset (path);
                device_removed (device);
            }
        }

        lock (media_players) {
            var media_player = media_players.get (path);
            if (media_player != null) {
                media_players.unset (path);
                media_player_removed (media_player);
            }
        }
    }

    public Gee.Collection<Services.Adapter> get_adapters () {
        lock (adapters) {
            return adapters.values;
        }
    }

    public Gee.Collection<Services.Device> get_devices () {
        lock (devices) {
            return devices.values;
        }
    }

    public Services.Adapter? get_adapter_from_path (string path) {
        lock (adapters) {
            return adapters.get (path);
        }
    }

    private void check_global_state () {
        global_state_changed (get_global_state (), get_connected ());
    }

    public bool get_connected () {
        lock (devices) {
            foreach (var device in devices.values) {
                if (device.connected) {
                    return true;
                }
            }
        }

        return false;
    }

    public bool get_global_state () {
        lock (adapters) {
            foreach (var adapter in adapters.values) {
                if (adapter.powered) {
                    return true;
                }
            }
        }

        return false;
    }

    public void set_global_state (bool state) {
        new Thread<void*> (null, () => {
            lock (devices) {
                foreach (var device in devices.values) {
                    if (device.connected) {
                        try {
                            device.disconnect ();
                        } catch (Error e) {
                            critical (e.message);
                        }
                    }
                }
            }

            lock (adapters) {
                foreach (var adapter in adapters.values) {
                    adapter.powered = state;
                }
            }

            return null;
        });
    }

    public void set_last_state () {
        check_global_state ();
    }
}
