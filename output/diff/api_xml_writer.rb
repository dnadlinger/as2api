# 
# Part of as2api - http://www.badgers-in-foil.co.uk/projects/as2api/
#
# Copyright (c) 2006 David Holroyd, and contributors.
#
# See the file 'COPYING' for terms of use of this code.
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
