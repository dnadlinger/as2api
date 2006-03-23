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

# Utility for generating API-describing XML data.
#
#   class MyWriter
#     include APIXMLWriter
#     
#     def write
#       File.open('api_data.xml') do |file|
#         @io = XMLWriter.new(file)
#         generate()
#       end
#     end
#     
#     def generate
#       api_api("name"=>"test", "version"=>"1.0") {
#         api_package("name"=>"test.package") {
#           ...
#         }
#       }
#     end
#   end
module APIXMLWriter

  private

  # The names of elements supported by this file format
  TAGS = [
    "api",
    "package",
    "class",
    "interface",
    "annotation",
    "description",
    "see",
    "implements",
    "constructor",
    "method",
    "param",
    "return",
    "field",
    "exception",
    "link"
  ]

  TAGS.each do |name|
    class_eval <<-HERE
      def api_#{name}(*args)
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
