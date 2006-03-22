# 
# Part of as2api - http://www.badgers-in-foil.co.uk/projects/as2api/
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#


def ensure_dir(path)
  path_components = path.split(File::SEPARATOR)
  base_path = nil
  if path_components.first == ""
    path_components.shift
    base_path = "/"
  end
  path_components.each do |part|
    if base_path.nil?
      base_path = part
    else
      base_path = File.join(base_path, part)
    end
    unless FileTest.exist?(base_path)
      Dir.mkdir(base_path)
    end
  end
end

def write_file(path, name)
  ensure_dir(path)
  name = File.join(path, name)
  File.open(name, "w") do |io|
    yield io
  end
end


# vim:softtabstop=2:shiftwidth=2
