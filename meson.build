project(
    'sound',
    'vala', 'c',
    version: '8.0.1',
    meson_version: '>= 0.57.0'
)

gettext_name = meson.project_name() + '-indicator'
gnome = import('gnome')
i18n = import('i18n')

prefix = get_option('prefix')
datadir = join_paths(prefix, get_option('datadir'))
libdir = join_paths(prefix, get_option('libdir'))

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(gettext_name), language:'c')

add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala'
)

add_project_arguments('-DG_LOG_DOMAIN="io.elementary.wingpanel.sound"', language:'c')

gresource = gnome.compile_resources(
    'gresource',
    'data' / 'gresource.xml',
    source_dir: 'data'
)

wingpanel_dep = dependency('wingpanel-8', version: '>=2.1.0')
wingpanel_indicatorsdir = wingpanel_dep.get_pkgconfig_variable('indicatorsdir', define_variable: ['libdir', libdir])

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name() + '-indicator')
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

shared_module(
    meson.project_name(),
    config_file,
    'src/Device.vala',
    'src/Indicator.vala',
    'src/Widgets/DisplayWidget.vala',
    'src/Widgets/Scale.vala',
    'src/Widgets/PlayerRow.vala',
    'src/Widgets/PlayerList.vala',
    'src/Widgets/DeviceManagerWidget.vala',
    'src/Widgets/DeviceItem.vala',
    'src/Services/PulseAudioManager.vala',
    'src/Services/MprisClient.vala',
    'src/Services/Volume-control.vala',
    'src/Services/Manager.vala',
    'src/Services/Device.vala',
    'src/Services/MediaPlayer.vala',
    'src/Services/ShellKeyGrabber.vala',
    gresource,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gio-2.0'),
        dependency('gobject-2.0'),
        dependency('granite-7', version: '>=6.0.0'),
        dependency('gtk4'),
        dependency('libpulse'),
        dependency('libpulse-mainloop-glib'),
        dependency('libnotify'),
        dependency('libcanberra'),
        # dependency('libcanberra-gtk4'),
        meson.get_compiler('vala').find_library('libpulse-ext', dirs: join_paths(meson.source_root(), 'vapi')),
        wingpanel_dep
    ],
    install: true,
    install_dir : wingpanel_indicatorsdir,
)

subdir('data')
subdir('po')

gnome.post_install(
    glib_compile_schemas: true
)
