/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class MaxWidthLabel : Gtk.Label {
    private int max_width;

    public MaxWidthLabel(int max_width) {
        this.max_width = max_width;
        // Fix this when on gtk 3.16
        this.set("xalign", 0);
    }

    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);
        if (minimum_width > max_width) {
            minimum_width = max_width;
        }
        if (natural_width > max_width) {
            natural_width = max_width;
        }
    }

}