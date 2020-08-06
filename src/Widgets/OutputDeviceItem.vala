public class OutputDeviceItem : Gtk.ListBoxRow {
    public signal void activated ();

    Gtk.Image img_type;
    Gtk.RadioButton radio_button;

    public OutputDeviceItem(string display_name, bool is_default, string? form_factor, Gtk.ListBoxRow? row) {
        radio_button = new Gtk.RadioButton.with_label (null, display_name);
        radio_button.active = is_default;
        radio_button.margin_start = 6;
        radio_button.hexpand = true;

        if (row != null) {
            var item = (OutputDeviceItem) row;
            radio_button.set_group (item.get_group ());
        }

        img_type = new Gtk.Image ();
        img_type.icon_name = get_icon_name (form_factor);
        img_type.icon_size = Gtk.IconSize.MENU;
        img_type.margin_end = 6;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.add (radio_button);
        grid.add (img_type);

        add (grid);

        radio_button.toggled.connect (() => {
            if (radio_button.active) {
                activated ();
            }
        });

        get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
    }

    public void set_default () {
        radio_button.active = true;
    }

    unowned SList get_group () {
        return radio_button.get_group ();
    }

    private string get_icon_name (string? form_factor) {
        switch (form_factor) {
            case "internal":
                return "audio-speakers";
            case "speaker":
                return "audio-speakers";
            case "handset":
                return "audio-headphones";
            case "tv":
                return "video-display";
            case "headphone":
                return "audio-headphones";
            case "hands-free":
                return "audio-headphones";
            case "computer":
                return "computer-laptop";
            default:
                return "audio-card";
        }
    }
}
