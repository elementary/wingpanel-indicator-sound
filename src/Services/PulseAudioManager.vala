// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright 2016-2018 elementary, Inc. (https://elementary.io)
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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

/*
 * Vocabulary of PulseAudio:
 *  - Source: Input (microphone)
 *  - Sink: Output (speaker)
 */

public class Sound.PulseAudioManager : GLib.Object {
    private static PulseAudioManager pam;
    private static bool debug_enabled;

    public static unowned PulseAudioManager get_default () {
        if (pam == null) {
            pam = new PulseAudioManager ();
        }

        return pam;
    }

    public signal void new_device (Device dev);

    private PulseAudio.Context context;
    private PulseAudio.GLibMainLoop loop;
    private bool is_ready = false;
    private uint reconnect_timer_id = 0U;
    private Gee.HashMap<string, Device> input_devices;
    private Gee.HashMap<string, Device> output_devices;
    public Device default_output { get; private set; }
    public Device default_input { get; private set; }
    private string default_source_name;
    private string default_sink_name;

    private PulseAudioManager () {

    }

    construct {
        loop = new PulseAudio.GLibMainLoop ();
        input_devices = new Gee.HashMap<string, Device> ();
        output_devices = new Gee.HashMap<string, Device> ();

        string messages_debug_raw = GLib.Environment.get_variable ("G_MESSAGES_DEBUG");
        if (messages_debug_raw != null) {
            string[]? messages_debug = messages_debug_raw.split (" ");
            debug_enabled = "all" in messages_debug || "debug" in messages_debug;
        }
    }

    public void start () {
        reconnect_to_pulse.begin ();
    }

    public async void set_default_device (Device device) {
        debug ("\n");
        debug ("set_default_device: %s", device.id);
        debug ("\t%s", device.direction.to_string ());
        // #1 Set card profile
        // Some sinks / sources are only available under certain card profiles,
        // for example to switch between onboard speakers to hdmi
        // the profile has to be switched from analog stereo to digital stereo.
        // Attempt to find profiles that support both selected input and output
        var other_device = default_input;
        var card_name = "card-sink-name";
        if (device.direction == OUTPUT) {
            other_device = default_output;
            card_name = "card-source-name";
        }

        var profile_name = device.get_matching_profile (other_device);
        // otherwise fall back to supporting this device only
        if (profile_name == null) {
            profile_name = device.profiles[0];
        }

        if (profile_name != device.card_active_profile_name) {
            debug ("set card profile: %s > %s", device.card_active_profile_name, profile_name);
            // switch profile to get sink for this device
            yield set_card_profile_by_index (device.card_index, profile_name);
            // wait for new card sink to appear
            debug ("wait for card sink / source");
            yield wait_for_update (device, card_name);
        }

        // #2 Set sink / source port
        // Speakers and headphones can be different ports on the same sink
        if (device.direction == OUTPUT && device.port_name != device.card_sink_port_name) {
            debug ("set sink port: %s > %s", device.card_sink_port_name, device.port_name);
            // set sink port (enables switching between headphones and speakers for example)
            yield set_sink_port_by_name (device.card_sink_name, device.port_name);
        }

        if (device.direction == INPUT && device.port_name != device.card_source_port_name) {
            debug ("set source port: %s > %s", device.card_source_port_name, device.port_name);
            yield set_source_port_by_name (device.card_source_name, device.port_name);
        }

        // #3 Wait for sink / source to appear for this device
        if (device.direction == OUTPUT && device.sink_name == null ||
            device.direction == INPUT && device.source_name == null) {
            debug ("wait for sink / source");
            yield wait_for_update (device, card_name);
        }

        // #4 Set sink / source
        // To for example switch between onboard speakers and bluetooth audio devices
        if (device.direction == OUTPUT && device.sink_name != default_sink_name) {
            debug ("set sink: %s > %s", default_sink_name, device.sink_name);
            yield set_default_sink (device.sink_name);
        }

        if (device.direction == INPUT && device.source_name != default_source_name) {
            debug ("set source: %s > %s", default_source_name, device.source_name);
            yield set_default_source (device.source_name);
        }
    }

    private async void set_card_profile_by_index (uint32 card_index, string profile_name) {
        context.set_card_profile_by_index (card_index, profile_name, (c, success) => {
            if (success == 1) {
                set_card_profile_by_index.callback ();
            } else {
                warning ("setting card %u profile to %s failed", card_index, profile_name);
            }
        });

        yield;
    }

    // TODO make more robust. Add timeout? Prevent multiple connects?
    private async void wait_for_update (Device device, string prop_name) {
        debug ("wait_for_update: %s:%s", device.id, prop_name);
        ulong handler_id = 0;
        handler_id = device.notify[prop_name].connect ((s, p) => {
            string prop_value;
            device.get (prop_name, out prop_value);
            if (prop_value != null) {
                device.disconnect (handler_id);
                wait_for_update.callback ();
            }
        });

        yield;
    }

    private async void set_sink_port_by_name (string sink_name, string port_name) {
        context.set_sink_port_by_name (sink_name, port_name, (c, success) => {
            if (success == 1) {
                set_sink_port_by_name.callback ();
            } else {
                warning ("setting sink %s port to %s failed", sink_name, port_name);
            }
        });

        yield;
    }

    private async void set_source_port_by_name (string source_name, string port_name) {
        context.set_source_port_by_name (source_name, port_name, (c, success) => {
            if (success == 1) {
                set_source_port_by_name.callback ();
            } else {
                warning ("setting source %s port to %s failed", source_name, port_name);
            }
        });

        yield;
    }

    private async void set_default_sink (string sink_name) {
        context.set_default_sink (sink_name, (c, success) => {
            if (success == 1) {
                set_default_sink.callback ();
            } else {
                warning ("setting default sink to %s failed", sink_name);
            }
        });

        yield;
    }

    private async void set_default_source (string source_name) {
        context.set_default_source (source_name, (c, success) => {
            if (success == 1) {
                set_default_source.callback ();
            } else {
                warning ("setting default source to %s failed", source_name);
            }
        });

        yield;
    }

    /*
     * Private methods to connect to the PulseAudio async interface
     */

    private bool reconnect_timeout () {
        reconnect_timer_id = 0U;
        reconnect_to_pulse.begin ();
        return false;
    }

    private async void reconnect_to_pulse () {
        if (is_ready) {
            context.disconnect ();
            context = null;
            is_ready = false;
        }

        var props = new PulseAudio.Proplist ();
        props.sets (PulseAudio.Proplist.PROP_APPLICATION_ID, "org.wingpanel.indicator.sound");
        context = new PulseAudio.Context (loop.get_api (), null, props);
        context.set_state_callback (context_state_callback);

        if (context.connect (null, PulseAudio.Context.Flags.NOFAIL, null) < 0) {
            warning ("pa_context_connect () failed: %s\n", PulseAudio.strerror (context.errno ()));
        }
    }

    private void context_state_callback (PulseAudio.Context c) {
        switch (c.get_state ()) {
            case PulseAudio.Context.State.READY:
                c.set_subscribe_callback (subscribe_callback);
                c.subscribe (PulseAudio.Context.SubscriptionMask.SERVER |
                             PulseAudio.Context.SubscriptionMask.SINK |
                             PulseAudio.Context.SubscriptionMask.SOURCE |
                             PulseAudio.Context.SubscriptionMask.SINK_INPUT |
                             PulseAudio.Context.SubscriptionMask.SOURCE_OUTPUT |
                             PulseAudio.Context.SubscriptionMask.CARD);
                context.get_server_info (server_info_callback);
                is_ready = true;
                break;

            case PulseAudio.Context.State.FAILED:
            case PulseAudio.Context.State.TERMINATED:
                if (reconnect_timer_id == 0U) {
                    reconnect_timer_id = Timeout.add_seconds (2, reconnect_timeout);
                }

                break;

            default:
                is_ready = false;
                break;
        }
    }

    /*
     * This is the main signal callback
     */

    private void subscribe_callback (PulseAudio.Context c, PulseAudio.Context.SubscriptionEventType t, uint32 index) {
        var source_type = t & PulseAudio.Context.SubscriptionEventType.FACILITY_MASK;
        switch (source_type) {
            case PulseAudio.Context.SubscriptionEventType.SINK:
            case PulseAudio.Context.SubscriptionEventType.SINK_INPUT:
                var event_type = t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK;
                switch (event_type) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        c.get_sink_info_by_index (index, sink_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        c.get_sink_info_by_index (index, sink_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        debug ("subscribe_callback:SINK:REMOVE");
                        foreach (var device in output_devices.values) {
                            if (device.sink_index == index) {
                                debug ("\tupdating device: %s", device.id);
                                device.sink_name = null;
                                device.sink_index = -1;
                                device.is_default = false;
                                debug ("\t\tdevice.sink_name: %s", device.sink_name);
                            }

                            if (device.card_sink_index == index) {
                                debug ("\tupdating device: %s", device.id);
                                device.card_sink_name = null;
                                device.card_sink_index = -1;
                                device.card_sink_port_name = null;
                                debug ("\t\tdevice.card_sink_name: %s", device.card_sink_name);
                            }
                        }

                        break;
                }

                break;

            case PulseAudio.Context.SubscriptionEventType.SERVER:
                context.get_server_info (server_info_callback);
                break;

            case PulseAudio.Context.SubscriptionEventType.CARD:
                var event_type = t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK;
                switch (event_type) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        c.get_card_info_by_index (index, card_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        c.get_card_info_by_index (index, card_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        remove_devices_by_card (output_devices, index);
                        remove_devices_by_card (input_devices, index);
                        break;
                }

                break;

            case PulseAudio.Context.SubscriptionEventType.SOURCE:
            case PulseAudio.Context.SubscriptionEventType.SOURCE_OUTPUT:
                var event_type = t & PulseAudio.Context.SubscriptionEventType.TYPE_MASK;
                switch (event_type) {
                    case PulseAudio.Context.SubscriptionEventType.NEW:
                        c.get_source_info_by_index (index, source_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.CHANGE:
                        c.get_source_info_by_index (index, source_info_callback);
                        break;

                    case PulseAudio.Context.SubscriptionEventType.REMOVE:
                        debug ("subscribe_callback:SOURCE:REMOVE");
                        foreach (var device in input_devices.values) {
                            if (device.source_index == index) {
                                debug ("\tupdating device: %s", device.id);
                                device.source_name = null;
                                device.source_index = -1;
                                device.is_default = false;
                                debug ("\t\tdevice.source_name: %s", device.source_name);
                            }

                            if (device.card_source_index == index) {
                                debug ("\tupdating device: %s", device.id);
                                device.card_source_name = null;
                                device.card_source_index = -1;
                                device.card_source_port_name = null;
                                debug ("\t\tdevice.card_source_name: %s", device.card_source_name);
                            }
                        }

                        break;
                }

                break;
        }
    }

    /*
     * Retrieve object informations
     */

    private void source_info_callback (PulseAudio.Context c, PulseAudio.SourceInfo? source, int eol) {
        if (source == null) {
            return;
        }

        // completely ignore monitors, they're not real sources
        if (source.monitor_of_sink != PulseAudio.INVALID_INDEX) {
            return;
        }

        debug ("source info update");
        debug ("\tsource: %s (%s)", source.description, source.name);
        debug ("\t\tcard: %u", source.card);

        if (source.name == "auto_null") {
            return;
        }

        if (debug_enabled) {
            foreach (var port in source.ports) {
                debug ("\t\tport: %s (%s)", port.description, port.name);
            }
        }

        if (source.active_port != null) {
            debug ("\t\tactive port: %s (%s)", source.active_port.description, source.active_port.name);
        }

        foreach (var device in input_devices.values) {
            if (device.card_index == source.card) {
                debug ("\t\tupdating device: %s", device.id);
                device.card_source_index = (int)source.index;
                device.card_source_name = source.name;
                debug ("\t\t\tdevice.card_source_name: %s", device.card_source_name);
                if (source.active_port != null && device.port_name == source.active_port.name) {
                    device.card_source_port_name = source.active_port.name;
                    device.source_name = source.name;
                    debug ("\t\t\tdevice.source_name: %s", device.card_source_name);
                    device.source_index = (int)source.index;
                    device.is_default = (source.name == default_source_name);
                    debug ("\t\t\tis_default: %s", device.is_default ? "true" : "false");

                    if (device.is_default) {
                        default_input = device;
                    }

                } else {
                    device.source_name = null;
                    device.source_index = -1;
                    device.is_default = false;
                }
            }
        }
    }

    private void sink_info_callback (PulseAudio.Context c, PulseAudio.SinkInfo? sink, int eol) {
        if (sink == null) {
            return;
        }

        debug ("sink info update");
        debug ("\tsink: %s (%s)", sink.description, sink.name);

        if (sink.name == "auto_null") {
            return;
        }

        debug ("\t\tcard: %u", sink.card);
        if (debug_enabled) {
            // Assuming that if sink.active_port is null, then sink.ports is empty
            foreach (var port in sink.ports) {
                debug ("\t\tport: %s (%s)", port.description, port.name);
            }
        }


        if (sink.active_port != null) {
            debug ("\t\tactive port: %s (%s)", sink.active_port.description, sink.active_port.name);
        }

        foreach (var device in output_devices.values) {
            if (device.card_index == sink.card) {
                debug ("\t\tupdating device: %s", device.id);
                device.card_sink_index = (int)sink.index;
                device.card_sink_name = sink.name;
                debug ("\t\t\tdevice.card_sink_name: %s", device.card_sink_name);

                if (sink.active_port != null && device.port_name == sink.active_port.name) {
                    device.card_sink_port_name = sink.active_port.name;
                    device.sink_name = sink.name;
                    debug ("\t\t\tdevice.sink_name: %s", device.card_sink_name);
                    device.sink_index = (int)sink.index;
                    device.is_default = (sink.name == default_sink_name);
                    debug ("\t\t\tis_default: %s", device.is_default ? "true" : "false");

                    if (device.is_default) {
                        default_output = device;
                    }

                } else {
                    device.sink_name = null;
                    device.sink_index = -1;
                    device.is_default = false;
                }
            }
        }
    }

    private void card_info_callback (PulseAudio.Context c, PulseAudio.CardInfo? card, int eol) {
        if (card == null) {
            return;
        }

        debug ("card info update");
        debug ("\tcard: %u %s (%s)", card.index, card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_DESCRIPTION),
               card.name);
        debug ("\t\tactive profile: %s", card.active_profile2.name);

        debug ("\t\tcard form factor: %s", card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR));
        debug ("\t\tcard icon name: %s", card.proplist.gets (PulseAudio.Proplist.PROP_MEDIA_ICON_NAME));

        var card_active_profile_name = card.active_profile2.name;

        // retrieve relevant ports
        PulseAudio.CardPortInfo*[] relevant_ports = {};
        uint32 highest_output_priority = 0;
        uint32 highest_input_priority = 0;
        foreach (var port in card.ports) {
            if (port.available == PulseAudio.PortAvailable.NO) {
                continue;
            }
            bool is_input = (PulseAudio.Direction.INPUT in port.direction);
            if (is_input && port.priority > highest_input_priority) {
                highest_input_priority = port.priority;
            }
            if (!is_input && port.priority > highest_output_priority) {
                highest_output_priority = port.priority;
            }
            relevant_ports += port;
        }

        // See DeviceManagerWidget.vala for the preferred-devices implementation
        var preferred_devices = Sound.Indicator.settings.get_value ("preferred-devices");
        var preferred_device_map = new Gee.HashMap<string, int32> ();
        var preferred_expiry = (int32)(GLib.get_real_time () / 1000000) - (86400 * 7); // Expire unused after 7 days
        foreach (var dev in preferred_devices) {
            var name = dev.get_child_value (0).get_string ();
            var last_used = dev.get_child_value (1).get_int32 ();
            preferred_device_map.set (name, last_used);
        }

        // add new / update devices
        foreach (var port in relevant_ports) {
            bool is_input = (PulseAudio.Direction.INPUT in port.direction);
            debug ("\t\t%s port: %s (%s)", is_input ? "input" : "output", port.description, port.name);
            Gee.HashMap<string, Device> devices = is_input? input_devices : output_devices;
            Device device = null;
            var id = get_device_id (card, port);
            bool is_new = !devices.has_key (id);
            if (is_new) {
                debug ("\t\t\tnew device: %s", id);
                device = new Device (id, card.index, port.name);
            } else {
                debug ("\t\t\tupdating device: %s", id);
                device = devices[id];
            }

            device.card_active_profile_name = card_active_profile_name;
            device.direction = port.direction;
            device.is_priority = port.priority == (is_input? highest_input_priority : highest_output_priority);
            // Any connected device previously selected in 7 days is also considered priority and will be displayed
            if (id in preferred_device_map.keys && preferred_device_map[id] > preferred_expiry) {
                device.is_priority = true;
            }
            var card_description = card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_DESCRIPTION);
            device.display_name = @"$(card_description): $(port.description)";
            device.form_factor = port.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
            if (device.form_factor == null) {
                device.form_factor = card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_FORM_FACTOR);
            }
            debug ("\t\t\tform factor: %s", device.form_factor);

            device.icon_name = port.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_ICON_NAME);
            if (device.icon_name == null) {
                device.icon_name = card.proplist.gets (PulseAudio.Proplist.PROP_DEVICE_ICON_NAME);
            }

            // Fallback to form_factor
            if (device.icon_name == null && device.form_factor != null) {
                switch (device.form_factor) {
                    case "car":
                        device.icon_name = "audio-car";
                        break;
                    case "computer":
                    case "internal":
                        device.icon_name = "computer";
                        break;
                    case "handset":
                        device.icon_name = "phone";
                        break;
                    case "headphone":
                        device.icon_name = "audio-headphones";
                        break;
                    case "hands-free":
                    case "headset":
                        device.icon_name = "audio-headset";
                        break;
                    case "hifi":
                        device.icon_name = "audio-subwoofer";
                        break;
                    case "microphone":
                        device.icon_name = "audio-input-microphone";
                        break;
                    case "portable":
                    case "speaker":
                        device.icon_name = "bluetooth";
                        break;
                    case "tv":
                        device.icon_name = "video-display-tv";
                        break;
                    case "webcam":
                        device.icon_name = "camera-web";
                        break;
                }
            }

            // Fallback to a generic icon name
            if (device.icon_name == null) {
                device.icon_name = is_input ? "audio-input-microphone" : "audio-card";
            }

            // audio card is currently represented by a speaker
            if (is_input && device.icon_name.has_prefix ("audio-card")) {
                device.icon_name = "audio-input-microphone";
            }

            device.profiles = get_relevant_card_port_profiles (port);
            if (debug_enabled) {
                foreach (var profile in device.profiles) {
                    debug ("\t\t\tprofile: %s", profile);
                }
            }

            if (is_new) {
                devices.set (id, device);
                new_device (device);
            }
        }

        cleanup_devices (output_devices, card, relevant_ports);
        cleanup_devices (input_devices, card, relevant_ports);
    }

    // remove devices which port has dissappeared
    private void cleanup_devices (Gee.HashMap<string, Device> devices,
                                  PulseAudio.CardInfo card,
                                  PulseAudio.CardPortInfo*[] relevant_ports) {
        var iter = devices.map_iterator ();
        while (iter.next ()) {
            var device = iter.get_value ();
            if (device.card_index != card.index) {
                continue;
            }

            // device still listed as port?
            var found = false;
            foreach (var port in relevant_ports) {
                if (device.id == get_device_id (card, port)) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                debug ("\t\tremoving device: %s", device.id);
                device.removed ();
                iter.unset ();
            }
        }
    }

    private static string get_device_id (PulseAudio.CardInfo card, PulseAudio.CardPortInfo* port) {
        return @"$(card.name):$(port.name)";
    }

    private Gee.ArrayList<string> get_relevant_card_port_profiles (PulseAudio.CardPortInfo* port) {
        var profiles_list = new Gee.ArrayList<PulseAudio.CardProfileInfo2*>.wrap (port.profiles2);

        // sort on priority;
        profiles_list.sort ((a, b) => {
            if (a.priority > b.priority) {
                return -1;
            }

            if (a.priority < b.priority) {
                return 1;
            }

            return 0;
        });

        // just store names in Device
        var profiles = new Gee.ArrayList<string> ();
        foreach (var item in profiles_list) {
            profiles.add (item.name);
        }

        return profiles;
    }

    private void remove_devices_by_card (Gee.HashMap<string, Device> devices, uint32 card_index) {
        var iter = devices.map_iterator ();
        while (iter.next ()) {
            var device = iter.get_value ();
            if (device.card_index == card_index) {
                debug ("removing device: %s", device.id);
                device.removed ();
                iter.unset ();
            }
        }
    }

    private void server_info_callback (PulseAudio.Context context, PulseAudio.ServerInfo? server) {
        debug ("server info update");
        if (server == null) {
            return;
        }

        if (default_sink_name == null) {
            default_sink_name = server.default_sink_name;
            debug ("\tdefault_sink_name: %s", default_sink_name);
        }

        if (default_sink_name != server.default_sink_name) {
            debug ("\tdefault_sink_name: %s > %s", default_sink_name, server.default_sink_name);
            default_sink_name = server.default_sink_name;
            PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_sink_callback);
        }

        if (default_source_name == null) {
            default_source_name = server.default_source_name;
            debug ("\tdefault_source_name: %s", default_source_name);
        }

        if (default_source_name != server.default_source_name) {
            debug ("\tdefault_source_name: %s > %s", default_source_name, server.default_source_name);
            default_source_name = server.default_source_name;
            PulseAudio.ext_stream_restore_read (context, ext_stream_restore_read_source_callback);
        }

        // request info on cards and ports before requesting info on
        // sinks, because sinks info is added to existing Devices.
        context.get_card_info_list (card_info_callback);
        context.get_source_info_list (source_info_callback);
        context.get_sink_info_list (sink_info_callback);
    }

    /*
     * Change the Source
     */

    private void ext_stream_restore_read_sink_callback (PulseAudio.Context c,
                                                        PulseAudio.ExtStreamRestoreInfo? info,
                                                        int eol) {
        if (eol != 0 || !info.name.has_prefix ("sink-input-by")) {
            return;
        }

        // We need to duplicate the info but with the right device name
        var new_info = PulseAudio.ExtStreamRestoreInfo ();
        new_info.name = info.name;
        new_info.channel_map = info.channel_map;
        new_info.volume = info.volume;
        new_info.mute = info.mute;
        new_info.device = default_sink_name;
        PulseAudio.ext_stream_restore_write (c, PulseAudio.UpdateMode.REPLACE, {new_info}, 1, (c, success) => {
            if (success != 1) {
                warning ("Updating source failed");
            }
        });
    }

    private void ext_stream_restore_read_source_callback (PulseAudio.Context c,
                                                          PulseAudio.ExtStreamRestoreInfo? info,
                                                          int eol) {
        if (eol != 0 || !info.name.has_prefix ("source-output-by")) {
            return;
        }

        // We need to duplicate the info but with the right device name
        var new_info = PulseAudio.ExtStreamRestoreInfo ();
        new_info.name = info.name;
        new_info.channel_map = info.channel_map;
        new_info.volume = info.volume;
        new_info.mute = info.mute;
        new_info.device = default_source_name;
        PulseAudio.ext_stream_restore_write (c, PulseAudio.UpdateMode.REPLACE, {new_info}, 1, null);
    }

}
