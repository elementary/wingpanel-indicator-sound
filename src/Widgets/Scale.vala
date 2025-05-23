/*
* Copyright 2015-2025 elementary, Inc. (https://elementary.io)
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
*
* Authored by: Sean Davis <sean@bluesabre.org>
*/

public class Sound.Widgets.Scale : Gtk.EventBox {
    public bool active { get; set; default = true; }
    public PulseAudio.Direction direction { get; set; }

    public Gtk.Adjustment adjustment { get; construct; }
    public string icon { get; construct set; }

    public Gtk.Scale scale_widget { get; private set; }

    private Gtk.ListBox device_list;
    private Gtk.Revealer devices_revealer;
    private unowned PulseAudioManager pam;

    public Scale (string icon, Gtk.Adjustment adjustment) {
        Object (
            icon: icon,
            adjustment: adjustment
        );
    }

    class construct {
        set_css_name ("device-manager");
    }

    construct {
        var image = new Gtk.Image.from_icon_name (icon, BUTTON);

        var toggle = new Gtk.ToggleButton ();
        toggle.image = image;

        scale_widget = new Gtk.Scale (HORIZONTAL, adjustment) {
            draw_value = false,
            hexpand = true,
            width_request = 175
        };

        var scale_box = new Gtk.Box (HORIZONTAL, 12) {
            hexpand = true,
            margin_top = 6,
            margin_start = 6,
            margin_bottom = 6,
            margin_end = 12
        };
        scale_box.add (toggle);
        scale_box.add (scale_widget);

        pam = PulseAudioManager.get_default ();
        pam.new_device.connect (add_device);
        pam.notify["default-output"].connect (default_output_changed);
        pam.notify["default-input"].connect (default_input_changed);
        pam.start ();

        device_list = new Gtk.ListBox () {
            activate_on_single_click = true,
            visible = true
        };

        var scrolled_box = new Gtk.ScrolledWindow (null, null) {
            child = device_list,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            propagate_natural_height = true,
            max_content_height = 256,
            margin_bottom = 3
        };

        devices_revealer = new Gtk.Revealer () {
            child = scrolled_box
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.add (scale_box);
        box.add (devices_revealer);

        child = box;
        add_events (Gdk.EventMask.SMOOTH_SCROLL_MASK);
        above_child = false;

        update_showable ();

        scale_widget.scroll_event.connect ((e) => {
            /* Re-emit the signal on the eventbox instead of using native handler */
            scroll_event (e);
            return Gdk.EVENT_STOP;
        });

        bind_property ("icon", image, "icon-name");

        bind_property ("active", scale_widget, "sensitive", BindingFlags.SYNC_CREATE);
        bind_property ("active", toggle, "active", BIDIRECTIONAL | SYNC_CREATE);
        bind_property ("active", toggle, "tooltip-text", SYNC_CREATE, (binding, srcval, ref targetval) => {
            if ((bool) srcval) {
                targetval.set_string (_("Mute"));
            } else {
                targetval.set_string (_("Unmute"));
            }

            return true;
        }, null);
    }

    private void add_device (Device device) {
        // Avoid Built-in Analog input - output devices
        if (device.direction != direction || device.port_name == "analog-output" || device.port_name == "analog-input") {
            return;
        }

        Gtk.ListBoxRow? row = device_list.get_row_at_index (0);
        var device_item = new DeviceItem (device, row);
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
        int32 now = (int32) (GLib.get_real_time () / 1000000);
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

    private void update_showable () {
        devices_revealer.reveal_child = device_list.get_row_at_index (1) != null;
    }

    private void default_output_changed () {
        pam.default_output.defaulted ();
    }

    private void default_input_changed () {
        pam.default_input.defaulted ();
    }
}
