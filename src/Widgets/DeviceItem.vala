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

public class DeviceItem : Gtk.ListBoxRow {
    public signal void activated ();

    private Gtk.Image img_type;
    private Gtk.RadioButton radio_button;

    public Gtk.ListBoxRow row { get; construct; }
    public string device_id { get; construct; }
    public string display_name { get; construct; }
    public string icon_name { get; construct; }
    public bool is_priority { get; construct; }
    public bool is_default { get; construct; }

    public DeviceItem (string device_id, string display_name, bool is_default, bool is_priority, string icon_name, Gtk.ListBoxRow? row) {
        Object (device_id: device_id, display_name: display_name, is_default: is_default, is_priority: is_priority, icon_name: icon_name, row: row);
    }

    class construct {
        set_css_name (Gtk.STYLE_CLASS_MENUITEM);
    }

    ~DeviceItem () {
        warning ("DeviceItem (%s) out!", device_id);
    }

    construct {
        selectable = false;
        var label = new Gtk.Label (display_name) {
            ellipsize = Pango.EllipsizeMode.MIDDLE
        };
        radio_button = new Gtk.RadioButton (null) {
            active = is_default,
            hexpand = true,
            xalign = 0
        };
        radio_button.add (label);

        if (row != null) {
            var item = (DeviceItem) row;
            radio_button.set_group (item.radio_button.get_group ());
        }

        img_type = new Gtk.Image () {
            icon_name = icon_name,
            icon_size = Gtk.IconSize.MENU
        };

        var grid = new Gtk.Grid () {
            column_spacing = 8
        };
        grid.add (radio_button);
        grid.add (img_type);

        add (grid);
        show_all ();
        no_show_all = true;

        radio_button.toggled.connect (() => {
            if (radio_button.active) {
                activated ();
            }
            update_visible (radio_button.active);
        });

        update_visible (is_default);
    }

    public void set_default () {
        radio_button.active = true;
        update_visible (true);
    }

    public void update_visible (bool is_default) {
        visible = is_priority || is_default;
    }

}
