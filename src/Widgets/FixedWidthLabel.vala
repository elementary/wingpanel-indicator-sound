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

public class FixedWidthLabel : Gtk.Label {
    private int fixed_width;

    public FixedWidthLabel(int fixed_width) {
        this.fixed_width = fixed_width;
        // Fix this when on gtk 3.16
        this.set("xalign", 0);
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        minimum_width = fixed_width;
        natural_width = fixed_width;
    }

}
