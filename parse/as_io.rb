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


# An IO-like object for reading from ActionScrpt source code.
# It's job is to filter out #include directives, so that these don't need to
# be handled at lexer or parser levels.
class ASIO
  def initialize(io)
    @io = io
  end

  def eof?
    @io.eof?
  end

  def readline
    @io.each_line do |line|
      return line unless handle_directives(line)
    end
  end

  def lineno
    @io.lineno
  end

  private

  def handle_directives(line)
    if line =~ /\s*#include/
      # TODO: Implement #include.  We just ignore, at the moment
      return true
    end
    return false
  end
end
