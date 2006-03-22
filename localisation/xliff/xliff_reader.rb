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

# So, this code is all a bit of a mess, tbh.  Once I've got a working codebase
# to look at, and I actually understand the indended use of the different
# parts of the XLIFF spec, this could all do with a nice rewrite


XLIFFFile = Struct.new(:original, :source_language, :target_language)


module TranslationHandler
  def start_file(file); end  
  def end_file; end  

  def start_trans_unit(id); end
  def end_trans_unit; end

  def start_source; end
  def end_source; end
  def start_target; end
  def end_target; end

  def text(text); end

  def ph(id); PhHandler.new; end
end

class PhHandler
  def start_ph; end
  def end_ph; end

  def start_sub; end
  def end_sub; end

  def text(text); end
end


class XLIFFReader

  def initialize(io, translation_handler)
    @doc = REXML::Document.new(io)
    @handler = translation_handler
  end

  def parse
    @doc.root.each_element("file") do |file_element|
      file = XLIFFFile.new
      file.original = file_element.attribute("original").value
      file.source_language = file_element.attribute("source-language").value
      file.target_language = file_element.attribute("target-language").value

      @handler.start_file(file)
      file_element.each_element("body/trans-unit") do |trans_unit_element|
	parse_trans_unit(trans_unit_element)
      end
      @handler.end_file
    end
  end

  def parse_trans_unit(trans_unit_element)
    id = trans_unit_element.attribute("id")
    @handler.start_trans_unit(id.value)
    trans_unit_element.each_element("source") do |source_element|
      parse_source(source_element)
    end
    trans_unit_element.each_element("target") do |target_element|
      parse_target(target_element)
    end
    @handler.end_trans_unit
  end

  def parse_source(source_element)
    return if source_element.size == 0

    @handler.start_source
    source_element.each_element do |element|
    end
    @handler.end_source
  end

  def parse_target(target_element)
    return if target_element.size == 0

    @handler.start_target
    target_element.each_child do |element|
      case element.node_type
	when :text
	  @handler.text(element.value)
	when :element
	  case element.name
	    when "ph"
	      parse_ph(element)
	    else
	      raise "unhandled element #{element.name.inspect}"
	  end
	else
	  raise "unhandled node type #{element.inspect}"
      end
    end
    @handler.end_target
  end

  def parse_ph(ph_element)
    ph_handler = @handler.ph(ph_element.attribute("id").value)
    ph_handler.start_ph
    ph_element.each_child do |element|
      case element.node_type
	when :text
	  ph_handler.text(element.value)
	when :element
	  case element.name
	    when "sub"
	      parse_sub(ph_handler, element)
	    else
	      raise "unhandled element #{element.name.inspect}"
	  end
	else
	  raise "unhandled node type #{element.inspect}"
      end
    end
    ph_handler.end_ph()
  end

  def parse_sub(ph_handler, sub_element)
    ph_handler.start_sub
    sub_element.each_child do |element|
      case element.node_type
	when :text
	  ph_handler.text(element.value)
	else
	  raise "unhandled node type #{element.inspect}"
      end
    end
    ph_handler.end_sub
  end
end

if __FILE__ == $0

  class MyListener
    include TranslationHandler

    def start_file(file); puts "file(#{file.original}),"; end
    def start_trans_unit(id); puts "  unit(#{id}),"; end
    def start_target; print "    target<"; end
    def end_target; puts ">"; end
    def text(text); print text; end
  end

  File.open(ARGV[0]) do |io|
    XLIFFReader.new(io, MyListener.new).parse
  end

end

# vim:sw=2:sts=2
