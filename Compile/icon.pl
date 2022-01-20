#
# Copyright (C) 2019 KSE Team
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# This script adds an icon to KSE's executable

use Win32::Exe;

if (($#ARGV + 1) != 2) {
    print "\nUsage: icon.pl <EXE> <ICON>";
    exit
}

$exe = Win32::Exe->new($ARGV[0]);
$exe->set_single_group_icon($ARGV[1]);
$exe->write;
