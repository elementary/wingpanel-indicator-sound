/*
* Copyright (c) 2015-2017 elementary LLC. (http://launchpad.net/wingpanel-indicator-sound)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

public class Sound.Services.Settings : Granite.Services.Settings {

    public double max_volume { get; set; }
    public string[] last_title_info { get; set; }

    private static Sound.Services.Settings? instance = null;

    public Settings () {
        base ("io.elementary.desktop.wingpanel.sound");
    }

    public static Sound.Services.Settings get_instance () {
        if (instance == null) {
            instance = new Sound.Services.Settings ();
        }

        return instance;
    }
}
