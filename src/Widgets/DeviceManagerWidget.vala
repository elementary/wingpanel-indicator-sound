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
    public bool is_input_manager;

    private unowned PulseAudioManager pam;

    construct {
        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-output"].connect (default_output_changed);
        pam.notify["default-input"].connect (default_input_changed);
        pam.start ();

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

    private void add_device (Device device) {
        if (device.input != is_input_manager) {
            return;
        }

        Gtk.ListBoxRow? row = device_list.get_row_at_index (0);
        var device_item = new DeviceItem (device.display_name,
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
        });

        device.defaulted.connect (() => {
            device_item.set_default ();
            update_preferred_devices (device);
            update_showable ();
        });

        update_showable ();
    }

    private void update_preferred_devices (Device device) {
        VariantBuilder builder = new VariantBuilder (new VariantType ("a{si}"));
        var preferred_devices = Sound.Indicator.settings.get_value ("preferred-devices");
        int32 now = (int32)(GLib.get_real_time () / 1000000);

        builder.add ("{si}", device.id, now);
        foreach (var dev in preferred_devices) {
            var name = dev.get_child_value (0).get_string ();
            var last_used = dev.get_child_value (1).get_int32 ();
            if (name == device.id) {
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

    private void default_output_changed () {
        pam.default_output.defaulted ();
    }

    private void default_input_changed () {
        pam.default_input.defaulted ();
    }
}
