/*
* Copyright 2015-2020 elementary, Inc. (https://elementary.io)
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

public class Sound.Indicator : Wingpanel.Indicator {
    public bool is_in_session { get; construct; }
    public bool natural_scroll_touchpad { get; set; }
    public bool natural_scroll_mouse { get; set; }
    public int volume_step { get; set; }

    private DisplayWidget display_widget;
    private Gtk.Box main_box;
    private Widgets.PlayerList mpris;
    private Widgets.Scale volume_scale;
    private Widgets.Scale mic_scale;
    private Widgets.DeviceManagerWidget output_device_manager;
    private Widgets.DeviceManagerWidget input_device_manager;
    private Gtk.Separator mic_separator;
    private Notify.Notification? notification;
    private Services.VolumeControlPulse volume_control;

    private ShellKeyGrabber? key_grabber = null;
    private ulong key_grabber_id = 0;
    private Gee.HashMultiMap<string, uint> saved_action_ids = new Gee.HashMultiMap<string, uint> ();

    private bool open = false;
    private bool mute_blocks_sound = false;
    private uint sound_was_blocked_timeout_id;

    private double max_volume = 1.0;

    private unowned Canberra.Context? ca_context = null;

    /* Smooth scrolling support */
    private double total_x_delta = 0;
    private double total_y_delta= 0;

    public static GLib.Settings settings;

    public Indicator (bool is_in_session) {
        Object (
            code_name: Wingpanel.Indicator.SOUND,
            is_in_session: is_in_session
        );
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.desktop.wingpanel.sound");
    }

    construct {
        GLib.Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        GLib.Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

        var touchpad_settings = new GLib.Settings ("org.gnome.desktop.peripherals.touchpad");
        touchpad_settings.bind ("natural-scroll", this, "natural-scroll-touchpad", SettingsBindFlags.DEFAULT);
        var mouse_settings = new GLib.Settings ("org.gnome.desktop.peripherals.mouse");
        mouse_settings.bind ("natural-scroll", this, "natural-scroll-mouse", SettingsBindFlags.DEFAULT);
        var gnome_settings = new GLib.Settings ("org.gnome.settings-daemon.plugins.media-keys");
        gnome_settings.bind ("volume-step", this, "volume-step", SettingsBindFlags.DEFAULT);

        visible = true;

        // Prevent a race that skips automatic resource loading
        // https://github.com/elementary/wingpanel-indicator-bluetooth/issues/203
        Gtk.IconTheme.get_default ().add_resource_path ("/org/elementary/wingpanel/icons");

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("io/elementary/wingpanel/sound/indicator.css");

        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        display_widget = new DisplayWidget ();

        volume_control = new Services.VolumeControlPulse (); /* sub-class of Services.VolumeControl */
        volume_control.notify["volume"].connect (on_volume_change);
        volume_control.notify["mic-volume"].connect (on_mic_volume_change);
        volume_control.notify["mute"].connect (on_mute_change);
        volume_control.notify["micMute"].connect (on_mic_mute_change);
        volume_control.notify["is-playing"].connect (on_is_playing_change);
        volume_control.notify["is-listening"].connect (update_mic_visibility);

        // Tooltip-related
        volume_control.notify["volume"].connect (update_tooltip);
        volume_control.notify["mute"].connect (update_tooltip);

        output_device_manager = new Widgets.DeviceManagerWidget () {
            direction = OUTPUT
        };
        input_device_manager = new Widgets.DeviceManagerWidget () {
            direction = INPUT
        };

        Notify.init ("wingpanel-indicator-sound");

        settings.notify["max-volume"].connect (set_max_volume);

        var locale = Intl.setlocale (LocaleCategory.MESSAGES, null);

        display_widget.volume_press_event.connect (volume_control.toggle_mute);
        display_widget.mic_press_event.connect (volume_control.toggle_mic_mute);

        display_widget.icon_name = get_volume_icon (volume_control.volume.volume);

        display_widget.volume_scroll_event.connect_after (on_volume_icon_scroll_event);
        display_widget.mic_scroll_event.connect_after (on_mic_icon_scroll_event);

        volume_scale = new Widgets.Scale ("audio-volume-high-symbolic", true, 0.0, max_volume, 0.01);

        mic_scale = new Widgets.Scale ("indicator-microphone-symbolic", true, 0.0, 1.0, 0.01);

        ca_context = CanberraGtk.context_get ();
        ca_context.change_props (Canberra.PROP_APPLICATION_NAME, "indicator-sound",
                                 Canberra.PROP_APPLICATION_ID, "wingpanel-indicator-sound",
                                 Canberra.PROP_APPLICATION_NAME, "start-here",
                                 Canberra.PROP_APPLICATION_LANGUAGE, locale,
                                 null);
        ca_context.open ();

        Bus.watch_name (BusType.SESSION, "org.gnome.Shell", BusNameWatcherFlags.NONE, on_watch, on_unwatch);

        settings.changed.connect ((key) => {
            if (key != "volume-up" &&
                key != "volume-down" &&
                key != "volume-mute") {
                return;
            }

            if (key_grabber != null) {
                ungrab_keybindings ();
                setup_grabs ();
            }
        });
    }

    private void on_watch (GLib.DBusConnection connection) {
        connection.get_proxy.begin<ShellKeyGrabber> (
            "org.gnome.Shell", "/org/gnome/Shell", NONE, null,
            (obj, res) => {
                try {
                    key_grabber = ((GLib.DBusConnection) obj).get_proxy.end<ShellKeyGrabber> (res);
                    setup_grabs ();
                } catch (Error e) {
                    critical (e.message);
                    key_grabber = null;
                }
            }
        );
    }

    private void on_unwatch (GLib.DBusConnection connection) {
        if (key_grabber_id != 0) {
            key_grabber.disconnect (key_grabber_id);
            key_grabber_id = 0;
        }
        key_grabber = null;
        critical ("Lost connection to org.gnome.Shell");
    }

    private void ungrab_keybindings () requires (key_grabber != null) {
        var actions = saved_action_ids.get_values ().to_array ();

        try {
            key_grabber.ungrab_accelerators (actions);
        } catch (Error e) {
            critical ("Couldn't ungrab accelerators: %s", e.message);
        }
    }

    private void setup_grabs () requires (key_grabber != null) {
        Accelerator[] accelerators = {};

        var volume_up_keybindings = settings.get_strv ("volume-up");
        for (int i = 0; i < volume_up_keybindings.length; i++) {
            accelerators += Accelerator () {
                name = volume_up_keybindings[i],
                mode_flags = ActionMode.NONE,
                grab_flags = Meta.KeyBindingFlags.NONE
            };
        }

        var volume_down_keybindings = settings.get_strv ("volume-down");
        for (int i = 0; i < volume_down_keybindings.length; i++) {
            accelerators += Accelerator () {
                name = volume_down_keybindings[i],
                mode_flags = ActionMode.NONE,
                grab_flags = Meta.KeyBindingFlags.NONE
            };
        }

        var volume_mute_keybindings = settings.get_strv ("volume-mute");
        for (int i = 0; i < volume_mute_keybindings.length; i++) {
            accelerators += Accelerator () {
                name = volume_mute_keybindings[i],
                mode_flags = ActionMode.NONE,
                grab_flags = Meta.KeyBindingFlags.IGNORE_AUTOREPEAT
            };
        }

        uint[] action_ids;
        try {
            action_ids = key_grabber.grab_accelerators (accelerators);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        for (int i = 0; i < action_ids.length; i++) {
            if (i < volume_up_keybindings.length) {
                saved_action_ids.@set ("volume-up", action_ids[i]);
            } else if (i < volume_up_keybindings.length + volume_down_keybindings.length) {
                saved_action_ids.@set ("volume-down", action_ids[i]);
            } else {
                saved_action_ids.@set ("volume-mute", action_ids[i]);
            }
        }

        key_grabber_id = key_grabber.accelerator_activated.connect (on_accelerator_activated);
    }

    private void on_accelerator_activated (uint action, GLib.HashTable<string, GLib.Variant> parameters_dict) {
        if (action in saved_action_ids["volume-up"]) {
            handle_change (1.0, false);
        } else if (action in saved_action_ids["volume-down"]) {
            handle_change (-1.0, false);
        } else if (action in saved_action_ids["volume-mute"]) {
            volume_control.toggle_mute ();
            notify_change (false);
        }
    }

    ~Indicator () {
        if (sound_was_blocked_timeout_id > 0) {
            Source.remove (sound_was_blocked_timeout_id);
        }

        if (notify_timeout_id > 0) {
            Source.remove (notify_timeout_id);
        }
    }

    private void set_max_volume () {
        var max = settings.get_double ("max-volume") / 100;
        // we do not allow more than 11db over the NORM volume
        var cap_volume = (double)PulseAudio.Volume.sw_from_dB (11.0) / PulseAudio.Volume.NORM;
        if (max > cap_volume) {
            max = cap_volume;
        }

        max_volume = max;
        on_volume_change ();
    }

    private void on_volume_change () {
        double volume = volume_control.volume.volume / max_volume;
        if (volume != volume_scale.scale_widget.get_value ()) {
            volume_scale.scale_widget.set_value (volume);
            display_widget.icon_name = get_volume_icon (volume);
        }
    }

    private void on_mic_volume_change () {
        var volume = volume_control.mic_volume;

        if (volume != mic_scale.scale_widget.get_value ()) {
            mic_scale.scale_widget.set_value (volume);
        }
    }

    private void on_mute_change () {
        volume_scale.active = !volume_control.mute;

        string volume_icon = get_volume_icon (volume_control.volume.volume);
        display_widget.icon_name = volume_icon;

        if (volume_control.mute) {
            volume_scale.icon = "audio-volume-muted-symbolic";
        } else {
            volume_scale.icon = volume_icon;
        }
    }

    private void on_mic_mute_change () {
        mic_scale.active = !volume_control.micMute;
        display_widget.mic_muted = volume_control.micMute;

        if (volume_control.micMute) {
            mic_scale.icon = "indicator-microphone-muted-symbolic";
        } else {
            mic_scale.icon = "indicator-microphone-symbolic";
        }
    }

    private void on_is_playing_change () {
        if (!volume_control.mute) {
            mute_blocks_sound = false;
            return;
        }
        if (volume_control.is_playing) {
            mute_blocks_sound = true;
        } else if (mute_blocks_sound) {
            /* Continue to show the blocking icon five seconds after a player has tried to play something */
            if (sound_was_blocked_timeout_id > 0) {
                Source.remove (sound_was_blocked_timeout_id);
            }

            sound_was_blocked_timeout_id = Timeout.add_seconds (5, () => {
                mute_blocks_sound = false;
                sound_was_blocked_timeout_id = 0;
                display_widget.icon_name = get_volume_icon (volume_control.volume.volume);
                return false;
            });
        }

        display_widget.icon_name = get_volume_icon (volume_control.volume.volume);
    }

    private void on_volume_icon_scroll_event (Gdk.EventScroll e) {
        double dir = 0.0;
        if (handle_scroll_event (e, out dir)) {
            handle_change (dir, false);
        }
    }

    private void on_mic_icon_scroll_event (Gdk.EventScroll e) {
        double dir = 0.0;
        if (handle_scroll_event (e, out dir)) {
            handle_change (dir, true);
        }
    }

    private void update_mic_visibility () {
        if (volume_control.is_listening) {
            mic_scale.no_show_all = false;
            mic_scale.show_all ();
            mic_separator.no_show_all = false;
            mic_separator.show ();
            input_device_manager.no_show_all = false;
            input_device_manager.show ();
            display_widget.show_mic = true;
        } else {
            mic_scale.no_show_all = true;
            mic_scale.hide ();
            mic_separator.no_show_all = true;
            mic_separator.hide ();
            input_device_manager.no_show_all = true;
            input_device_manager.hide ();
            display_widget.show_mic = false;
        }
    }

    private unowned string get_volume_icon (double volume) {
        if (volume <= 0 || this.volume_control.mute) {
            return this.mute_blocks_sound ? "audio-volume-muted-blocking-symbolic" : "audio-volume-muted-symbolic";
        } else if (volume <= 0.3) {
            return "audio-volume-low-symbolic";
        } else if (volume <= 0.7) {
            return "audio-volume-medium-symbolic";
        } else {
            return "audio-volume-high-symbolic";
        }
    }

    private void on_volume_switch_change () {
        if (volume_scale.active) {
            volume_control.set_mute (false);
        } else {
            volume_control.set_mute (true);
        }
    }

    private void on_mic_switch_change () {
        if (mic_scale.active) {
            volume_control.set_mic_mute (false);
        } else {
            volume_control.set_mic_mute (true);
        }
    }

    public override Gtk.Widget get_display_widget () {
        return display_widget;
    }


    public override Gtk.Widget? get_widget () {
        if (main_box == null) {
            mpris = new Widgets.PlayerList ();

            volume_scale.active = !volume_control.mute;
            volume_scale.scale_widget.set_value (volume_control.volume.volume);
            volume_scale.icon = get_volume_icon (volume_scale.scale_widget.get_value ());

            set_max_volume ();

            mic_scale.active = !volume_control.micMute;

            mic_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

            update_mic_visibility ();

            var settings_button = new Gtk.ModelButton () {
                text = _("Sound Settings…"),
                margin_top = 3
            };

            main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            if (is_in_session) {
                main_box.add (mpris);
                main_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            }
            main_box.add (volume_scale);
            main_box.add (output_device_manager);
            if (is_in_session) {
                main_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
                main_box.add (mic_scale);
                main_box.add (input_device_manager);
                main_box.add (mic_separator);
                main_box.add (settings_button);
            }

            mic_scale.notify["active"].connect (on_mic_switch_change);

            mic_scale.scale_widget.value_changed.connect (() => {
                volume_control.mic_volume = mic_scale.scale_widget.get_value ();
            });

            mic_scale.scale_widget.button_release_event.connect (() => {
                notify_change (true);
                return false;
            });

            mic_scale.scroll_event.connect_after ((e) => {
                double dir = 0.0;
                if (handle_scroll_event (e, out dir)) {
                    handle_change (dir, true);
                }

                return true;
            });

            mpris.close.connect (() => {
                close ();
            });

            settings_button.clicked.connect (() => {
                show_settings ();
            });

            volume_control.notify["headphone-plugged"].connect (() => {
                if (!volume_control.headphone_plugged) {
                    mpris.pause_all ();
                }
            });

            volume_scale.scale_widget.button_release_event.connect ((e) => {
                notify_change (false);
                return false;
            });

            volume_scale.scroll_event.connect_after ((e) => {
                double dir = 0.0;
                if (handle_scroll_event (e, out dir)) {
                    handle_change (dir, false);
                }

                return true;
            });

            volume_scale.notify["active"].connect (on_volume_switch_change);

            volume_scale.scale_widget.value_changed.connect (() => {
                var val = volume_scale.scale_widget.get_value () * max_volume;
                var vol = new Services.VolumeControl.Volume () {
                    volume = val.clamp (0.0, max_volume),
                    reason = Services.VolumeControl.VolumeReasons.USER_KEYPRESS
                };
                volume_control.volume = vol;
                volume_scale.icon = get_volume_icon (volume_scale.scale_widget.get_value ());
            });
        }

        return main_box;
    }

    /* Handles both SMOOTH and non-SMOOTH events.
     * In order to deliver smooth volume changes it:
     * * accumulates very small changes until they become significant.
     * * ignores rapid changes in direction.
     * * responds to both horizontal and vertical scrolling.
     * In the case of diagonal scrolling, it ignores the event unless movement in one direction
     * is more than twice the movement in the other direction.
     */
    private bool handle_scroll_event (Gdk.EventScroll e, out double dir) {
        dir = 0.0;
        bool natural_scroll;
        var event_source = e.get_source_device ().input_source;
        if (event_source == Gdk.InputSource.MOUSE) {
            natural_scroll = natural_scroll_mouse;
        } else if (event_source == Gdk.InputSource.TOUCHPAD) {
            natural_scroll = natural_scroll_touchpad;
        } else {
            natural_scroll = false;
        }

        switch (e.direction) {
            case Gdk.ScrollDirection.SMOOTH:
                    var abs_x = double.max (e.delta_x.abs (), 0.0001);
                    var abs_y = double.max (e.delta_y.abs (), 0.0001);

                    if (abs_y / abs_x > 2.0) {
                        total_y_delta += e.delta_y;
                    } else if (abs_x / abs_y > 2.0) {
                        total_x_delta += e.delta_x;
                    }

                break;

            case Gdk.ScrollDirection.UP:
                total_y_delta = -1.0;
                break;
            case Gdk.ScrollDirection.DOWN:
                total_y_delta = 1.0;
                break;
            case Gdk.ScrollDirection.LEFT:
                total_x_delta = -1.0;
                break;
            case Gdk.ScrollDirection.RIGHT:
                total_x_delta = 1.0;
                break;
            default:
                break;
        }

        if (total_y_delta.abs () > 0.5) {
            dir = natural_scroll ? total_y_delta : -total_y_delta;
        } else if (total_x_delta.abs () > 0.5) {
            dir = natural_scroll ? -total_x_delta : total_x_delta;
        }

        if (dir.abs () > 0.0) {
            total_y_delta = 0.0;
            total_x_delta = 0.0;
            return true;
        }

        return false;
    }

    private void handle_change (double change, bool is_mic) {
        double v;

        if (is_mic) {
            v = volume_control.mic_volume;
        } else {
            v = volume_control.volume.volume;
        }

        var new_v = (v + (double)volume_step * change / 100.0).clamp (0.0, max_volume);

        if (new_v == v) {
            /* Ignore if no volume change will result */
            return;
        }

        if (is_mic) {
            volume_control.mic_volume = new_v;
        } else {
            var vol = new Services.VolumeControl.Volume ();
            vol.reason = Services.VolumeControl.VolumeReasons.USER_KEYPRESS;
            vol.volume = new_v;
            volume_control.volume = vol;
        }

        notify_change (is_mic);
    }

    public override void opened () {
        open = true;

        mpris.update_default_player ();

        if (notification != null) {
            try {
                notification.close ();
            } catch (Error e) {
                warning ("Unable to close sound notification: %s", e.message);
            }

            notification = null;
        }
    }

    public override void closed () {
        open = false;
        notification = null;
    }

    private void show_settings () {
        close ();

        try {
            AppInfo.launch_default_for_uri ("settings://sound", null);
        } catch (Error e) {
            warning ("%s\n", e.message);
        }
    }

    uint notify_timeout_id = 0;
    private void notify_change (bool is_mic) {
        if (notify_timeout_id > 0) {
            return;
        }

        notify_timeout_id = Timeout.add (50, () => {
            bool notification_showing = false;
            /* Show notification if not open */
            if (!open) {
                notification_showing = show_notification (is_mic);
            }

            /* If open or no notification shown, just play sound */
            /* TODO: Should this be suppressed if mic is on? */
            if (!notification_showing) {
                Canberra.Proplist props;
                Canberra.Proplist.create (out props);
                props.sets (Canberra.PROP_CANBERRA_CACHE_CONTROL, "volatile");
                props.sets (Canberra.PROP_EVENT_ID, "audio-volume-change");
                ca_context.play_full (0, props);
            }

            notify_timeout_id = 0;
            return false;
        });
    }

    /* This also plays a sound. TODO Is there a way of suppressing this if mic is on? */
    private bool show_notification (bool is_mic) {
        if (notification == null) {
            notification = new Notify.Notification ("indicator-sound", "", "");
            notification.set_hint ("x-canonical-private-synchronous", new Variant.string ("indicator-sound"));
        }

        if (notification != null) {
            string icon;

            if (is_mic) {
                if (volume_control.mic_volume <= 0 || volume_control.micMute) {
                    icon = "microphone-sensitivity-muted-symbolic";
                } else {
                    icon = "audio-input-microphone-symbolic";
                }
            } else {
                icon = get_volume_icon (volume_scale.scale_widget.get_value ());
            }

            notification.update ("indicator-sound", "", icon);

            int32 volume;
            if (is_mic) {
                volume = (int32)Math.round (volume_control.mic_volume / max_volume * 100.0);
            } else {
                volume = (int32)Math.round (volume_control.volume.volume / max_volume * 100.0);
            }

            notification.set_hint ("value", new Variant.int32 (volume));

            try {
                notification.show ();
            } catch (Error e) {
                warning ("Unable to show sound notification: %s", e.message);
                notification = null;
                return false;
            }
        } else {
            return false;
        }

        return true;
    }

    private void update_tooltip () {
        string description = _("Volume: %.0f%%").printf (
            (volume_control.mute) ? 0 : volume_control.volume.volume * 100
        );
        string accel_label = (volume_control.mute) ? _("Middle-click to unmute") : _("Middle-click to mute");

        accel_label = Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (accel_label);
        display_widget.tooltip_markup = "%s\n%s".printf (description, accel_label);
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("Activating Sound Indicator");

    var indicator = new Sound.Indicator (server_type == SESSION);
    return indicator;
}
