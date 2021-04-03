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

    Gtk.Image img_type;
    Gtk.RadioButton radio_button;
    bool is_priority;

    public DeviceItem (string display_name, bool is_default, bool _is_priority, string icon_name, Gtk.ListBoxRow? row) {
        is_priority = _is_priority;
        selectable = false;
        radio_button = new Gtk.RadioButton.with_label (null, display_name) {
            active = is_default,
            hexpand = true,
            xalign = 0
        };

        if (row != null) {
            var item = (DeviceItem) row;
            radio_button.set_group (item.get_group ());
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

        get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
    }

    public void set_default () {
        radio_button.active = true;
        update_visible (true);
    }

    public void update_visible (bool is_default) {
        visible = is_priority || is_default;
    }

    unowned SList get_group () {
        return radio_button.get_group ();
    }
}
