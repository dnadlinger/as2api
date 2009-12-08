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


require 'xmlwriter'
require 'output/xml/xml_formatter'
require 'output/diff/api_xml_writer'

# The #serialize_api method of this class will write a description of the
# types given, as XML, to the IO given to #new
class APISerializer
  include APIXMLWriter

  # Creates an APISerializer which writes data to the given IO, and which will
  # embed the given api_name and api_version into the resulting XML.
  def initialize(io, api_name, api_version)
    # APIWriter will use the @io attribute,
    @io = XMLFormatter.new(XMLWriter.new(io))
    @io.inlines(["see", "description", "param", "return", "link", "exception"])
    @api_name = api_name
    @api_version = api_version
  end

  # writes XML describing the given types to the IO passed to the constructor
  def serialize_api(type_aggregator)
    api_api("name"=>@api_name, "version"=>@api_version) {
      type_aggregator.each_package do |aspackage|
	serialize_package(aspackage)
      end
    }
  end

  private

  def serialize_package(aspackage)
    attrs = {}
    attrs["name"] = aspackage.name unless aspackage.default?
    api_package(attrs) {
      aspackage.each_type do |astype|
	serialize_type(astype)
      end
    }
  end

  def serialize_type(astype)
    if astype.is_a?(ASClass)
      serialize_class(astype)
    else
      serialize_interface(astype)
    end
  end

  def serialize_class(asclass)
    attrs = {"name"=>asclass.unqualified_name}
    if asclass.has_ancestor?
      attrs["extends"] = asclass.extends.resolved_type.qualified_name
    end
    api_class(attrs) {
      asclass.each_interface do |asinterface|
	if asinterface.resolved?
	  api_implements("interface"=>asinterface.resolved_type.qualified_name)
	end
      end
      serialize_annotation(asclass.comment) if asclass.comment
      serialize_all_fields(asclass)
      serialize_all_methods(asclass)
    }
  end

  def serialize_interface(asinterface)
    attrs = {"name"=>asinterface.unqualified_name}
    if asinterface.has_ancestor?
      attrs["extends"] = asinterface.extends.resolved_type.qualified_name
    end
    api_interface(attrs) {
      serialize_annotation(asinterface.comment) if asinterface.comment
      serialize_all_methods(asinterface)
    }
  end

  def serialize_all_fields(asclass)
    asclass.each_field do |asfield|
      serialize_field(asfield)
    end
  end

  def serialize_all_methods(astype)
    astype.each_method do |asmethod|
      serialize_method(asmethod)
    end
  end

  def serialize_field(asfield)
    # TODO: some handling of explicit vs implict field stuff
    attrs = {"name"=>asfield.name}
    attrs["visibility"] = asfield.access.visibility.to_s if asfield.access.visibility
    attrs["static"] = "true" if asfield.access.static?
    attrs["type"] = asfield.field_type.local_name if asfield.field_type
    api_field(attrs) {
      serialize_annotation(asfield.comment) if asfield.comment
    }
  end

  def serialize_method(asmethod)
    attrs = {"name"=>asmethod.name}
    attrs["visibility"] = asmethod.access.visibility.to_s if asmethod.access.visibility
    attrs["static"] = "true" if asmethod.access.static?
    api_method(attrs) {
      serialize_annotation(asmethod.comment) if asmethod.comment
      serialize_all_params(asmethod)
      serialize_return(asmethod)
      serialize_all_exceptions(asmethod) if asmethod.comment
    }
  end

  def serialize_all_params(asmethod)
    asmethod.arguments.each do |asarg|
      serialize_param(asarg, asmethod.comment)
    end
  end

  def serialize_param(asarg, comment)
    attrs = {"name"=>asarg.name}
    attrs["type"] = asarg.arg_type.local_name if asarg.arg_type
    api_param(attrs) {
      if comment
	param_doc = comment.find_param(asarg.name)
	if param_doc
	  serialize_comment_inlines(param_doc)
	end
      end
    }
  end

  def serialize_all_exceptions(asmethod)
    asmethod.comment.each_exception do |throws_block|
      api_exception("type"=>throws_block.exception_type.local_name) {
	serialize_comment_inlines(throws_block)
      }
    end
  end

  def serialize_return(asmethod)
    attrs = {}
    attrs["type"] = asmethod.return_type.local_name if asmethod.return_type
    api_return(attrs) {
      if asmethod.comment
	return_doc = asmethod.comment.find_return
	if return_doc
	  serialize_comment_inlines(return_doc)
	end
      end
    }
  end

  def serialize_annotation(comment)
    api_annotation {
      if comment.description
	serialize_description(comment.description)
      end
      comment.each_seealso do |seealso|
	serialize_seealso(seealso)
      end
    }
  end

  def serialize_description(description)
    api_description {
      serialize_comment_inlines(description)
    }
  end

  def serialize_seealso(seealso)
    link = seealso.inlines.first
    attrs = {}
    ref = link.target_ref
    case ref
      when TypeRef
	attrs["type"]=ref.local_name
      when MethodRef
	attrs["type"]=ref.type_local_name
	attrs["method"]=ref.member_name
      when MemberRef
	attrs["type"]=ref.type_local_name
	attrs["field"]=ref.member_name
    end
    if link.text && link.text!=""
      api_see(link.text, attrs)
    else
      api_see(attrs)
    end
  end

  def serialize_comment_inlines(comment_block)
    comment_block.each_inline do |inline|
      case inline
	when String
	  pcdata(inline)
	when LinkTag
	  serialize_link_tag(inline)
	when CodeTag
          serialize_code_tag(inline)
	else
	  raise "unhandled inline #{inline.inspect}"
      end
    end
  end
  
  def serialize_code_tag(code)
    attrs = {}
    api_code(code.text, attrs)
  end

  def serialize_link_tag(link)
    attrs = {}
    ref = link.target_ref
    case ref
      when TypeRef
	attrs["type"]=ref.local_name
      when MethodRef
	attrs["type"]=ref.type_local_name
	attrs["method"]=ref.member_name
      when MemberRef
	attrs["type"]=ref.type_local_name
	attrs["field"]=ref.member_name
    end
    if link.text && link.text!=""
      api_link(link.text, attrs)
    else
      api_link(attrs)
    end
  end
end

# vim:sw=2:sts=2
