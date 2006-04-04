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


require 'rexml/document'
require 'rexml/streamlistener'

# Reads data from an XML stream and notifies an instance of APIListener about
# the structures the stream contains.
class APIXMLReader
  include REXML::StreamListener

  # Creates an instance that will call methods on the given APIListener as
  # elements are seen during reading.
  def initialize(api_listener)
    @listener = api_listener
  end

  # parses XML data from the given stream, and sends the data to the
  # APIListener that was given to the constructor.
  def read(io)
    REXML::Document.parse_stream(io, self)
  end

  def tag_start(name, attrs)
    case name
      when "api"
	@listener.start_api(attrs["name"], attrs["version"])
      when "package"
	@listener.start_package(attrs["name"])
      when "class"
	@listener.start_class(attrs["name"], attrs["extends"])
      when "interface"
	@listener.start_interface(attrs["name"], attrs["extends"])
      when "annotation"
	@listener.start_annotation
      when "description"
	@listener.start_description
      when "see"
	kind = member = nil
	if attrs["method"]
	  kind = :method
	  member = attrs["method"]
	elsif attrs["field"]
	  kind = :field
	  member = attrs["field"]
	end
	@listener.start_see(attrs["type"], kind, member)
      when "link"
	kind = member = nil
	if attrs["method"]
	  kind = :method
	  member = attrs["method"]
	elsif attrs["field"]
	  kind = :field
	  member = attrs["field"]
	end
	@listener.start_link(attrs["type"], kind, member)
      when "implements"
	@listener.implements(attrs["interface"])
      when "constructor"
	@listener.start_constructor
      when "method"
	vis = attrs["visibility"] ? attrs["visibility"].to_sym : nil
	@listener.start_method(attrs["name"], vis, attrs["static"]=="true")
      when "param"
	@listener.start_param(attrs["name"], attrs["type"])
      when "return"
	@listener.start_return(attrs["type"])
      when "field"
	vis = attrs["visibility"] ? attrs["visibility"].to_sym : nil
	@listener.start_field(attrs["name"], attrs["type"], vis, attrs["static"]=="true")
      when "exception"
	@listener.start_exception(attrs["type"])
      else
	raise "unknown tag #{name.inspect}"
    end
  end

  def tag_end(name)
    @listener.send("end_#{name}") unless NOEND.include?(name)
  end

  def text(text)
    @listener.text(text)
  end

  private

  # elements which are expected to be empty tags (and so will not have an
  # end-tag).
  NOEND = [
    "implements"
  ]
end


# Module providing empty implementations of the methods called by APIXMLReader
# as it encounters API decriptors in an XML stream.  If you want to parse an
# API XML file, but aren't interested in all the events the parser produces,
# include this module in your listner implementation.
module APIListener
  def text(text); end

  def start_api(name); end
  def end_api; end
  def start_package(name); end
  def end_package; end
  def start_class(name, extends); end
  def end_class; end
  def start_interface(name, extends); end
  def end_interface; end
  def start_annotation; end
  def end_annotation; end
  def start_description; end
  def end_description; end
  def start_see(type, kind, member); end
  def end_see; end
  def start_link(type, kind, member); end
  def end_link; end
  def implements(interface); end
  def start_constructor; end
  def end_constructor; end
  def start_method(name, visibility, static); end
  def end_method; end
  def start_param(name, type); end
  def end_param; end
  def start_return(type); end
  def end_return; end
  def start_field(name, type, visibility, static); end
  def end_field; end
  def start_exception(type); end
  def end_exception; end
end

# vim:sw=2:sts=2
