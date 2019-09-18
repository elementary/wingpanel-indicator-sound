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
 * You should have received a copy of the GNU General Public
 * License along with this program; If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Fiorotto Giuliano <mr.fiorotto@gmail.com>
 *              Fabio Zaramella <ffabio.96.x@gmail.com>
 */

[DBus (name = "org.bluez.MediaPlayer1")]
public interface Sound.Services.MediaPlayer : Object {
    public abstract void play () throws GLib.Error;
    public abstract void pause () throws GLib.Error;
    public abstract void stop () throws GLib.Error;
    public abstract void next () throws GLib.Error;
    public abstract void previous () throws GLib.Error;
    public abstract void fast_forward () throws GLib.Error;
    public abstract void rewind () throws GLib.Error;
    public abstract string name { public owned get; }
    public abstract string status { public owned get; }
    public abstract HashTable<string,Variant> track { public owned get; }
}
