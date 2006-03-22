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

module XHTMLWriter

  private

  TAGS = [
    "br",
    "span",
    "abbr",
    "acronym",
    "cite",
    "code",
    "dfn",
    "em",
    "kbd",
    "q",
    "samp",
    "strong",
    "var",
    "div",
    "p",
    "address",
    "blockquote",
    "pre",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "a",
    "dl",
    "dt",
    "dd",
    "ol",
    "ul",
    "li",
    "ins",
    "del",
    "bdo",
    "ruby",
    "rbc",
    "rtc",
    "rb",
    "rt",
    "rp",
    "b",
    "big",
    "i",
    "small",
    "sub",
    "sup",
    "tt",
    "hr",
    "link",
    "meta",
    "base",
    "script",
    "noscript",
    "style",
    "img",
    "area",
    "map",
    "param",
    "object",
    "table",
    "caption",
    "thead",
    "tfoot",
    "tbody",
    "colgroup",
    "col",
    "tr",
    "th",
    "td",
    "form",
    "label",
    "input",
    "select",
    "optgroup",
    "option",
    "textarea",
    "fieldset",
    "legend",
    "button",
    "title",
    "head",
    "body",
    "html"
  ]

  TAGS << "frameset" << "noframes" << "frame"

  TAGS.each do |name|
    class_eval <<-HERE
      def html_#{name}(*args)
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

# vim:sw=2
