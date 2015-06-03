/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
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

public class Sound.Widgets.Scale : Gtk.Grid {
    private Gtk.Image image;
    private Gtk.Switch switch_widget;
    private Gtk.Scale scale_widget;

    public Scale (string icon, bool active = false, double min, double max, double step) {
        this.hexpand = true;
        var image_box = new Gtk.EventBox ();
        image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.DIALOG);
        image_box.halign = Gtk.Align.START;
        image_box.add (image);

        this.attach (image_box, 0, 0, 1, 1);

        scale_widget = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step);
        scale_widget.margin_start = 6;
        scale_widget.set_size_request (175, -1);
        scale_widget.set_draw_value (false);
        scale_widget.hexpand = true;
        this.attach (scale_widget, 1, 0, 1, 1);

        switch_widget = new Gtk.Switch ();
        switch_widget.active = active;
        switch_widget.halign = Gtk.Align.END;
        switch_widget.margin_start = 6;
        switch_widget.margin_end = 0;

        this.attach (switch_widget, 2, 0, 1, 1);

        this.get_style_context ().add_class ("indicator-switch");

        this.add_events (Gdk.EventMask.SCROLL_MASK);
        image_box.add_events (Gdk.EventMask.SCROLL_MASK);
        switch_widget.add_events (Gdk.EventMask.SCROLL_MASK);
        // delegate all scroll events to the scale
        this.scroll_event.connect (on_scroll);
        image_box.scroll_event.connect (on_scroll);
        switch_widget.scroll_event.connect (on_scroll);
    }

    private bool on_scroll (Gdk.EventScroll event) {
        scale_widget.scroll_event (event);

        return Gdk.EVENT_STOP;
    }

    public Gtk.Image get_image () {
        return image;
    }

    public void set_icon (string icon) {
        image.set_from_icon_name (icon, Gtk.IconSize.DIALOG);
    }

    public void set_active (bool active) {
        switch_widget.set_active (active);
    }

    public bool get_active () {
        return switch_widget.get_active ();
    }

    public Gtk.Switch get_switch () {
        return switch_widget;
    }

    public Gtk.Scale get_scale () {
        return scale_widget;
    }
}
