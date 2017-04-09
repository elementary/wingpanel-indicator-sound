# Wingpanel Sound Indicator
[![l10n](https://l10n.elementary.io/widgets/desktop/wingpanel-indicator-sound/svg-badge.svg)](https://l10n.elementary.io/projects/desktop/wingpanel-indicator-sound)

## Building and Installation

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`

    sudo make install
