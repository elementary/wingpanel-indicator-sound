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

public class Sound.Widgets.IndicatorScale : Gtk.Grid {
	private Gtk.Image image;
	private Gtk.Switch switch_widget;
	private Gtk.Scale scale_widget;

	public IndicatorScale (string icon, bool active = false, double min, double max, double step) {
		this.hexpand = true;
		this.margin_top = 6;
		this.margin_bottom = 3;
		this.margin_start = 6;
		this.margin_end = 6;

		image = new Gtk.Image.from_icon_name (icon, Gtk.IconSize.LARGE_TOOLBAR);
		image.halign = Gtk.Align.START;
		image.margin_start = 6;

		this.attach (image, 0, 0, 1, 1);

		scale_widget = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, min, max, step);
		scale_widget.margin_start = 12;
		scale_widget.set_size_request (175, -1);
		scale_widget.set_draw_value (false);
		this.attach (scale_widget, 1, 0, 1, 1);

		switch_widget = new Gtk.Switch ();
		switch_widget.active = active;
		switch_widget.halign = Gtk.Align.END;
		switch_widget.margin_start = 12;

		this.attach (switch_widget, 2, 0, 1, 1);

		this.get_style_context ().add_class ("indicator-switch");
	}

	public void set_icon (string icon) {
		image.set_from_icon_name (icon, Gtk.IconSize.LARGE_TOOLBAR);
	}

	// TODO: Add get_caption () method when that markup-stuff is away

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
