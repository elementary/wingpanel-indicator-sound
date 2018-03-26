/*
* Copyright (c) 2015-2018 elementary LLC. (https://elementary.io)
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
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

public class Sound.Widgets.Scale : Gtk.Grid {
    private Gtk.Image image;

    private string _icon;
    public string icon {
        get {
            return _icon;
        }
        set {
            image.set_from_icon_name (value, Gtk.IconSize.DIALOG);
            _icon = value;
        }
    }

    public bool active { get; construct set; }
    public double max { get; construct; }
    public double min { get; construct; }
    public double step { get; construct; }
    public Gtk.Scale scale_widget { get; private set; }

    public Scale (string icon, bool active = false, double min, double max, double step) {
        Object (
            active: active,
            icon: icon,
            max: max,
            min: min,
            step: step
        );
    }

    construct {
        image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.DIALOG);
        image.pixel_size = 48;

        var image_box = new Gtk.EventBox ();
        image_box.add (image);

        scale_widget = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step);
        scale_widget.margin_start = 6;
        scale_widget.set_size_request (175, -1);
        scale_widget.set_draw_value (false);
        scale_widget.hexpand = true;

        var switch_widget = new Gtk.Switch ();
        switch_widget.valign = Gtk.Align.CENTER;
        switch_widget.margin_start = 6;
        switch_widget.margin_end = 12;

        hexpand = true;
        get_style_context ().add_class ("indicator-switch");
        add (image_box);
        add (scale_widget);
        add (switch_widget);

        add_events (Gdk.EventMask.SCROLL_MASK);
        scroll_event.connect (on_scroll);

        image_box.add_events (Gdk.EventMask.SCROLL_MASK);
        image_box.add_events (Gdk.EventMask.BUTTON_RELEASE_MASK);
        image_box.scroll_event.connect (on_scroll);
        image_box.button_release_event.connect (() => {
            switch_widget.active = !switch_widget.active;
            return Gdk.EVENT_STOP;
        });

        switch_widget.add_events (Gdk.EventMask.SCROLL_MASK);
        switch_widget.scroll_event.connect (on_scroll);
        switch_widget.bind_property ("active", scale_widget, "sensitive", BindingFlags.SYNC_CREATE);
        switch_widget.bind_property ("active", image, "sensitive", BindingFlags.SYNC_CREATE);
        switch_widget.bind_property ("active", this, "active", BindingFlags.BIDIRECTIONAL);
    }

    private bool on_scroll (Gdk.EventScroll event) {
        scale_widget.scroll_event (event);
        return Gdk.EVENT_STOP;
    }
}
