# Wingpanel Sound Indicator
[![Translation status](https://l10n.elementary.io/widgets/wingpanel/-/wingpanel-indicator-sound/svg-badge.svg)](https://l10n.elementary.io/engage/wingpanel/?utm_source=widget)

![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

    libcanberra-gtk-dev
    libcanberra-gtk3-dev
    libgranite-dev
    libglib2.0-dev
    libgtk-3-dev
    libnotify-dev
    libpulse-dev
    libwingpanel-dev
    meson
    valac (>= 0.26)

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
