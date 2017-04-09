# Wingpanel Sound Indicator
[![l10n](https://l10n.elementary.io/widgets/desktop/wingpanel-indicator-sound/svg-badge.svg)](https://l10n.elementary.io/projects/desktop/wingpanel-indicator-sound)

## Building and Installation

You'll need the following dependencies:

    cmake
    libcanberra-gtk-dev
    libgranite-dev
    libglib2.0-dev
    libgtk-3-dev
    libnotify-dev
    libpulse-dev
    libwingpanel-2.0-dev
    valac (>= 0.26)

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`

    sudo make install
