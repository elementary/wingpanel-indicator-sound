public class Sound.Device : GLib.Object {
    public class Port {
        public string name;
        public string description;
        public uint32 priority;
    }

    public signal void removed ();
    public signal void defaulted ();

    // info from card and ports
    public bool input { get; set; default=true; }
    public string id { get; construct; }
    public uint32 card_index { get; construct; }
    public string port_name { get; construct; }
    public string display_name { get; set; }
    public string form_factor { get; set; }
    public Gee.ArrayList<string> profiles { get; set; }
    public string card_active_profile_name { get; set; }

    // sink info
    public string? sink_name { get; set; }
    public int sink_index { get; set; }
    public string? card_sink_name { get; set; }
    public string? card_sink_port_name { get; set; }
    public int card_sink_index { get; set; }

    // source info
    public string? source_name { get; set; }
    public int source_index { get; set; }
    public string? card_source_name { get; set; }
    public string? card_source_port_name { get; set; }
    public int card_source_index { get; set; }

    // info from source or sink
    public bool is_default { get; set; default=false; }
    public bool is_priority { get; set; default=false; }

    public Device (string id, uint32 card_index, string port_name) {
        Object (id: id, card_index: card_index, port_name: port_name);
    }

    construct {
        profiles = new Gee.ArrayList<string> ();
    }

    public string get_nice_icon () {
        switch (form_factor) {
            case "handset":
                return "audio-headset-symbolic";
            case "headset":
                return "audio-headset-symbolic";
            case "headphone":
                return "audio-headphones-symbolic";
            case "hifi":
                return "audio-card-symbolic";
            case "microphone":
                return "audio-input-microphone-symbolic";
            default:
                return input? "audio-input-microphone-symbolic" : "audio-speakers-symbolic";
        }
    }

    public string? get_matching_profile (Device? other_device) {
        if (other_device != null) {
            foreach (var profile in profiles) {
                if (other_device.profiles.contains (profile)) {
                    return profile;
                }
            }
        }

        return null;
    }
}
