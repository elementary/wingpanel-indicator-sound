/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2021-2024 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Sean Davis <sean@bluesabre.org>
 */

public class Sound.Widgets.DeviceItem : Gtk.ListBoxRow {
    public signal void activated ();

    public Sound.Device device { get; construct; }
    public Gtk.ListBoxRow? row { get; construct; }

    private bool is_priority;
    private Gtk.CheckButton radio_button;

    public DeviceItem (Device device, Gtk.ListBoxRow? row) {
        Object (device: device, row: row);
    }

    class construct {
        set_css_name ("modelbutton");
    }

    construct {
        var label = new Gtk.Label (device.display_name) {
            halign = START,
            hexpand = true,
            ellipsize = MIDDLE
        };

        var image = new Gtk.Image.from_icon_name (device.icon_name + "-symbolic") {
            use_fallback = true
        };

        var box = new Gtk.Box (HORIZONTAL, 6);
        box.append (label);
        box.append (image);

        radio_button = new Gtk.CheckButton () {
            child = box,
            active = device.is_default,
            hexpand = true,
            // xalign = 0
        };

        if (row != null) {
            var item = (DeviceItem) row;
            radio_button.set_group (item.radio_button);
        }

        child = radio_button;

        selectable = false;
        visible = false;

        radio_button.toggled.connect (() => {
            if (radio_button.active) {
                activated ();
            }
            update_visible (radio_button.active);
        });

        is_priority = device.is_priority;
        update_visible (device.is_default);
    }

    public void set_default () {
        radio_button.active = true;
        is_priority = true;
        visible = true;
    }

    private void update_visible (bool is_default) {
        visible = is_priority || is_default;
    }
}
