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

module XLIFFWriter
  private

  TAGS = [
    "alt-trans",
    "bin-source",
    "bin-target",
    "bin-unit",
    "body",
    "bpt",
    "bx",
    "context",
    "context-group",
    "count",
    "count-group",
    "ept",
    "ex",
    "external-file",
    "file",
    "g",
    "glossary",
    "group",
    "header",
    "internal-file",
    "it",
    "mrk",
    "note",
    "ph",
    "phase",
    "phase-group",
    "prop",
    "prop-group",
    "reference",
    "skl",
    "source",
    "sub",
    "target",
    "tool",
    "trans-unit",
    "x",
    "xliff"
  ]


  TAGS.each do |name|
    class_eval <<-HERE
      def xliff_#{name.gsub(/-/, "_")}(*args)
	if block_given?
	  @io.element("#{name}", *args) { yield }
	else
	  if args.length == 0
	    @io.empty_tag("#{name}")
	  else
	    if args[0].instance_of?(String)
	      @io.simple_element("#{name}", *args)
	    else
	      @io.empty_tag("#{name}", *args)
	    end
	  end
	end
      end
    HERE
  end

  public

  def pcdata(text)
    @io.pcdata(text)
  end

  def pi(text)
    @io.pi(text)
  end

  def comment(text)
    @io.comment(text)
  end

  def doctype(name, syspub, public_id, system_id)
    @io.doctype(name, syspub, public_id, system_id)
  end

  def passthrough(text)
    @io.passthrough(text)
  end

  def xml; @io end
end
