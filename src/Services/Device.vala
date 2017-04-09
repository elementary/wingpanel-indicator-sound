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
 */

[DBus (name = "org.bluez.Device1")]
public interface Sound.Services.Device : Object {
	public abstract void cancel_pairing () throws IOError;
	public abstract void connect () throws IOError;
	public abstract void connect_profile (string UUID) throws IOError;
	public abstract void disconnect () throws IOError;
	public abstract void disconnect_profile (string UUID) throws IOError;
	public abstract void pair () throws IOError;

	public abstract string[] UUIDs { public owned get; private set; }
	public abstract bool blocked { public owned get; public set; }
	public abstract bool connected { public owned get; private set; }
	public abstract bool legacy_pairing { public owned get; private set; }
	public abstract bool paired { public owned get; private set; }
	public abstract bool trusted { public owned get; public set; }
	public abstract int16 RSSI { public owned get; private set; }
	public abstract ObjectPath adapter { public owned get; private set; }
	public abstract string address { public owned get; private set; }
	public abstract string alias { public owned get; public set; }
	public abstract string icon { public owned get; private set; }
	public abstract string modalias { public owned get; private set; }
	public abstract string name { public owned get; private set; }
	public abstract uint16 appearance { public owned get; private set; }
	public abstract uint32 @class { public owned get; private set; }
}
