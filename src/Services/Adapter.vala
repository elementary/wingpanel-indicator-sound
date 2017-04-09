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

[DBus (name = "org.bluez.Adapter1")]
public interface Sound.Services.Adapter : Object {
	public abstract void remove_device (ObjectPath device) throws IOError;
	public abstract void set_discovery_filter (HashTable<string, Variant> properties) throws IOError;
	public abstract void start_discovery () throws IOError;
	public abstract void stop_discovery () throws IOError;

	public abstract string[] UUIDs { owned get; }
	public abstract bool discoverable { get; set; }
	public abstract bool discovering { get; }
	public abstract bool pairable { get; set; }
	public abstract bool powered { get; set; }
	public abstract string address { owned get; }
	public abstract string alias { owned get; set; }
	public abstract string modalias { owned get; }
	public abstract string name { owned get; }
	public abstract uint32 @class { get; }
	public abstract uint32 discoverable_timeout { get; set; }
	public abstract uint32 pairable_timeout { get; set; }
}
