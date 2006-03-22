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

class XMLWriter
  def initialize(io)
    @io = io
  end

  def doctype(name, syspub, public_id, system_id)
    @io.puts("<!DOCTYPE #{name} #{syspub} \"#{public_id}\" \"#{system_id}\">")
  end

  def element(text, attrs=nil)
    start_tag(text, attrs)
    yield
    end_tag(text)
  end

  def simple_element(text, body, attrs=nil)
    start_tag(text, attrs)
    pcdata(body)
    end_tag(text)
  end

  def start_tag(text, attrs=nil)
    chk_name(text)
    @io.print('<')
    @io.print(text)
    attrs(attrs)
    @io.print('>')
  end

  def empty_tag(text, attrs=nil)
    chk_name(text)
    @io.print('<')
    @io.print(text)
    attrs(attrs)
    @io.print('/>')
  end

  def end_tag(text)
    chk_name(text)
    @io.print('</')
    @io.print(text)
    @io.print('>')
  end

  def pcdata(text)
    @io.print(text.gsub(/&/, '&amp;').gsub(/</, '&lt;').gsub(/>/, '&gt;'))
  end

  def cdata(text)
    raise "CDATA text must not contain ']]>'" if text =~ /\]\]>/
    @io.print("<![CDATA[")
    @io.print(text)
    @io.print("]]>")
  end

  def comment(text)
    raise "comment must not contain '--'" if text =~ /--/
    @io.print("<!--")
    @io.print(text)
    @io.print("-->")
  end

  def pi(text)
    raise "processing instruction must not contain '?>'" if text =~ /\?>/
    @io.print("<?")
    @io.print(text)
    @io.print("?>")
  end

  def passthrough(text)
    @io.print(text)
  end

  private
  def chk_name(name)
    raise "bad character '#{$&}' in tag name #{name}" if name =~ /[<>& "']/
  end

  def attrs(attrs)
    unless attrs.nil?
      attrs.each do |key, val|
      	raise "#{key.inspect}=#{val.inspect}" if key.nil? || val.nil?
	@io.print(' ')
	@io.print(key)
	@io.print('="')
	@io.print(val.gsub(/"/, "&quot;"))
	@io.print('"')
      end
    end
  end
end
