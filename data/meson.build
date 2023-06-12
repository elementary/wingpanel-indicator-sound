i18n.merge_file(
    input: 'sound.metainfo.xml.in',
    output: 'io.elementary.wingpanel.sound.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)


install_data(
    'io.elementary.desktop.wingpanel.sound.gschema.xml',
    install_dir: join_paths(datadir, 'glib-2.0', 'schemas')
)
