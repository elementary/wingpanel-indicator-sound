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
    public string card_name { get; set; }
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
    public bool is_muted { get; set; default=false; }
    public PulseAudio.CVolume cvolume { get; set; }
    public double volume { get; set; default=0; }
    public float balance { get; set; default=0; }
    public PulseAudio.ChannelMap channel_map { get; set; }
    public Gee.LinkedList<PulseAudio.Operation> volume_operations;

    public Device (string id, uint32 card_index, string port_name) {
        Object (id: id, card_index: card_index, port_name: port_name);
    }

    construct {
        volume_operations = new Gee.LinkedList<PulseAudio.Operation> ();
        profiles = new Gee.ArrayList<string> ();
    }

    public string get_nice_form_factor () {
        switch (form_factor) {
            case "internal":
                return _("Built-in");
            case "speaker":
                return _("Speaker");
            case "handset":
                return _("Handset");
            case "tv":
                return _("TV");
            case "webcam":
                return _("Webcam");
            case "microphone":
                return _("Microphone");
            case "headset":
                return _("Headset");
            case "headphone":
                return _("Headphone");
            case "hands-free":
                return _("Hands-Free");
            case "car":
                return _("Car");
            case "hifi":
                return _("HiFi");
            case "computer":
                return _("Computer");
            case "portable":
                return _("Portable");
            default:
                return input? _("Input") : _("Output");
        }
    }

    private const string BASE_ICON_NAME = "audio-";
    private const string SYMBOLIC = "-symbolic";
    public string get_nice_icon () {
        string modifier;
        switch (form_factor) {
            case "handset":
                modifier = "headset";
                break;
            case "headset":
                modifier = "headset";
                break;
            case "headphone":
                modifier = "headphones";
                break;
            case "hifi":
                modifier = "card";
                break;
            default:
                modifier = "speakers";
                break;
        }
        return BASE_ICON_NAME + modifier + SYMBOLIC;
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
