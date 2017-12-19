# Wingpanel Sound Indicator
[![l10n](https://l10n.elementary.io/widgets/desktop/wingpanel-indicator-sound/svg-badge.svg)](https://l10n.elementary.io/projects/desktop/wingpanel-indicator-sound)

![Screenshot](data/screenshot.png?raw=true)

## Building and Installation

You'll need the following dependencies:

    libcanberra-gtk-dev
    libgranite-dev
    libglib2.0-dev
    libgtk-3-dev
    libnotify-dev
    libpulse-dev
    libwingpanel-2.0-dev
    meson
    valac (>= 0.26)

Run `meson` to configure the build environment and then `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`

    sudo ninja install
