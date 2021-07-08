// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Sean Davis <sean@bluesabre.org>
 */

public class Sound.Widgets.DeviceManagerWidget : Gtk.Grid {
    private Gtk.ListBox device_list;
    private Gtk.ScrolledWindow scrolled_box;
    public bool is_input_manager { get; construct; }

    private unowned PulseAudioManager pam;

    public DeviceManagerWidget (bool is_input_manager) {
        Object (is_input_manager: is_input_manager);
    }

    construct {
        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.update_device.connect (update_device);
        pam.disconnected.connect (disconnected);
        if (is_input_manager) {
            pam.notify["default-input"].connect (default_changed);
        } else {
            pam.notify["default-output"].connect (default_changed);
        }

        device_list = new Gtk.ListBox () {
            activate_on_single_click = true,
            visible = true
        };

        scrolled_box = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            propagate_natural_height = true,
            max_content_height = 256,
            no_show_all = true
        };
        scrolled_box.add (device_list);

        attach (scrolled_box, 0, 1, 1);

        update_showable ();
    }

    public void clear () {
        foreach (Gtk.Widget child in device_list.get_children ()) {
            device_list.remove (child);
            child.destroy ();
        }
    }

    private void disconnected () {
        clear ();
    }

    private void update_device (Device device) {
        if (device.input != is_input_manager) {
            return;
        }
        foreach (unowned var child in device_list.get_children ()) {
            if (device.id == ((DeviceItem) child).device_id) {
                return;
            }
        }
        add_device (device);
    }

    private void add_device (Device device) {
        if (device.input != is_input_manager) {
            return;
        }

        Gtk.ListBoxRow? row = device_list.get_row_at_index (0);
        var device_item = new DeviceItem (device.id,
                                          device.display_name,
                                          device.is_default,
                                          device.is_priority,
                                          device.get_nice_icon (),
                                          row);
        device_list.add (device_item);

        device_item.activated.connect (() => {
            pam.set_default_device.begin (device);
            update_preferred_devices (device);
        });

        device.removed.connect (() => {
            device_list.remove (device_item);
            device_list.show_all ();
            update_showable ();
            device_item.destroy ();
        });

        device.defaulted.connect (() => {
            device_item.set_default ();
            update_preferred_devices (device);
            update_showable ();
        });

        if (device.is_default) {
            device_item.set_default ();
        }

        update_showable ();
    }

    /**
     * Preferred devices are stored as:
     * {
     *   device_a: last_used_unix_timestamp,
     *   device_b: last_used_unix_timestamp
     * }
     * If a device hasn't been selected in 7 days, it is removed from preferred devices.
     * Device selection happens when the user selects the device, and when the plugin
     * is initialized.
     */
    private void update_preferred_devices (Device device) {
        VariantBuilder builder = new VariantBuilder (new VariantType ("a{si}"));
        var preferred_devices = Sound.Indicator.settings.get_value ("preferred-devices");
        int32 now = (int32)(GLib.get_real_time () / 1000000);
        int32 preferred_expiry = now - (86400 * 7); // Expire unused after 7 days

        builder.add ("{si}", device.id, now);
        foreach (var dev in preferred_devices) {
            var name = dev.get_child_value (0).get_string ();
            var last_used = dev.get_child_value (1).get_int32 ();
            if (name == device.id) {
                continue;
            }
            if (last_used < preferred_expiry) {
                continue;
            }
            builder.add ("{si}", name, last_used);
        }
        Variant dictionary = builder.end ();

        device.is_priority = true;
        Sound.Indicator.settings.set_value ("preferred-devices", dictionary);
    }

    private uint n_visible_items () {
        uint n = 0;
        foreach (unowned var device in device_list.get_children ()) {
            if (device.visible) {
                n++;
            }
        }
        return n;
    }

    private void update_showable () {
        if (n_visible_items () <= 1) {
            scrolled_box.hide ();
        } else {
            scrolled_box.show ();
        }
    }

    private void default_changed () {
        unowned var output = is_input_manager ? pam.default_input : pam.default_output;
        if (output != null)
            output.defaulted ();
    }

}
