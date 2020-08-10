public class Sound.Widgets.Toggler : Gtk.Button {

    public bool expanded = false;

    private Gtk.Label toggler_label;
    private Gtk.Label secondary_level;
    private Gtk.Image toggler_image;

    construct {
        hexpand = true;
        vexpand = true;

        toggler_label = new Gtk.Label ("<b>%s</b>".printf ("Sound Output Device"));
        toggler_label.halign = Gtk.Align.START;
        toggler_label.valign = Gtk.Align.END;
        toggler_label.vexpand = true;
        toggler_label.use_markup = true;

        secondary_level = new Gtk.Label (null);
        secondary_level.halign = Gtk.Align.START;
        secondary_level.valign = Gtk.Align.START;
        secondary_level.vexpand = true;

        toggler_image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        toggler_image.halign = Gtk.Align.END;
        toggler_image.valign = Gtk.Align.CENTER;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 6;
        grid.margin_end = 6;
        grid.attach (toggler_image, 0, 0, 1, 2);
        grid.attach (toggler_label, 1, 0, 2, 1);
        grid.attach (secondary_level, 1, 1, 1, 1);

        add (grid);

        get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
    }

    public void change_primary_device (string name) {
        secondary_level.set_label (name);
        secondary_level.show_all ();
    }
}
