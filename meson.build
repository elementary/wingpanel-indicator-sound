project('sound', 'vala', 'c')

gettext_name = meson.project_name() + '-indicator'
gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_name), language:'c')

wingpanel_dep = dependency('wingpanel-2.0')

asresources = gnome.compile_resources(
    'as-resources', 'data/mask.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

shared_module(
    meson.project_name(),
    'src/Indicator.vala',
    'src/Widgets/DisplayWidget.vala',
    'src/Widgets/MaxWidthLabel.vala',
    'src/Widgets/Scale.vala',
    'src/Widgets/MprisGui.vala',
    'src/Widgets/MprisWidget.vala',
    'src/Services/MprisClient.vala',
    'src/Services/Settings.vala',
    'src/Services/Volume-control.vala',
    'src/Services/Manager.vala',
    'src/Services/Adapter.vala',
    'src/Services/Device.vala',
    'src/Services/MediaPlayer.vala',
    asresources,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        dependency('libpulse'),
        dependency('libpulse-mainloop-glib'),
        dependency('libnotify'),
        dependency('libcanberra'),
        dependency('libcanberra-gtk'),
        wingpanel_dep
    ],
    install: true,
    install_dir : wingpanel_dep.get_pkgconfig_variable('indicatorsdir')
)

install_data(
    'schemas/org.pantheon.desktop.wingpanel.indicators.sound.gschema.xml',
    install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

subdir('po')

meson.add_install_script('meson/post_install.py')
