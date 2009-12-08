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


require 'output/diff/api_xml_reader'
require 'api_loader'

# Recreates an API model from a serialized XML stream created by APISerializer
#
#   File.open('api_data.xml') do |io|
#     deser = APIDeserializer.new(io)
#     type_aggregator, api_name, api_version = deser.deserialize_api
#   end
#
class APIDeserializer
  def initialize(io)
    @io = io
  end

  # returns a 3 element array containing a GlobalTypeAggregator instance,
  # the API name and the API version (both Strings).
  def deserialize_api
    listener = DeserializerAPIListener.new
    reader = APIXMLReader.new(listener)
    reader.read(@io)
    [listener.type_aggregator, listener.api_name, listener.api_version]
  end

  private

  class DeserializerAPIListener

    def initialize
      @type_aggregator = nil
      @text_handler_stack = []
      @api_name = nil
      @api_version = nil
    end

    attr_accessor :type_aggregator, :api_name, :api_version

    def text(text)
      #return unless @current_comment_block
      #@current_comment_block.add_inline(text)
      @text_handler_stack.last.text(text) unless @text_handler_stack.empty?
    end

    def start_api(name, version)
      @type_aggregator = GlobalTypeAggregator.new
      @api_name = name
      @api_version = version
    end
    def end_api
      resolver = TypeResolver.new([])
      class << resolver
	# prevent errors from being reported (TODO define a nicer API),
	def err(filename, lineno, msg); end
      end
      resolver.resolve_types(@type_aggregator)
    end

    def start_package(name)
      @current_package_name = name
    end
    def end_package; end

    def start_class(name, extends)
      @current_api_element = @current_type = ASClass.new(@current_package_name, name)
      @current_type.type_namespace = TypeLocalNamespace.new(@current_type)
      @current_type.import_list = ImportList.new
      if extends
	@current_type.extends = ref_to(extends)
      end
    end

    def end_class
      @type_aggregator.add_type(@current_type)
      @current_type = nil
    end
    def start_interface(name, extends)
      @current_api_element = @current_type = ASInterface.new(@current_package_name, name)
      @current_type.type_namespace = TypeLocalNamespace.new(@current_type)
      @current_type.import_list = ImportList.new
      if extends
	@current_type.extends = ref_to(extends)
      end
    end
    def end_interface
      @type_aggregator.add_type(@current_type)
      @current_type = nil
    end

    def start_annotation
      @comment_data = @current_api_element.comment || CommentData.new
    end
    def end_annotation
      @current_api_element.comment = @comment_data
      @comment_data = nil
    end

    class CommentBlockTextHandler
      def initialize(comment_block)
	@comment_block = comment_block
      end

      def text(text)
	@comment_block.add_inline(text)
      end
    end

    class SeeBlockTextHandler < CommentBlockTextHandler
      def text(text)
	if @comment_block.inlines[0].text
	  # unlikely case, maybe a comment splitting the text?
	  @comment_block.inlines[0].text << text
	else
	  @comment_block.inlines[0].text = text.dup
	end
      end
    end

    class LinkBlockTextHandler
      def initialize(link_tag)
	@link_tag = link_tag
      end
      def text(text)
	if @link_tag.text
	  # unlikely case, maybe a comment splitting the text?
	  @link_tag.text << text
	else
	  @link_tag.text = text.dup
	end
      end
    end
   
    def push_text_handler(handler)
      @text_handler_stack.push(handler)
    end

    def pop_text_handler
      @text_handler_stack.pop
    end

    def start_description
      @current_comment_block = BlockTag.new
      push_text_handler(CommentBlockTextHandler.new(@current_comment_block))
    end
    def end_description
      @comment_data.add_block(@current_comment_block)
      @current_comment_block = nil
      pop_text_handler
    end

    def start_see(type, kind, member)
      @current_comment_block = SeeBlockTag.new
      push_text_handler(SeeBlockTextHandler.new(@current_comment_block))
      lineno = 0
      type_ref = ref_to(type) if type
      ref = nil
      case kind
	when :method
	  ref = type_ref.ref_method(member, nil)
	when :field
	  ref = type_ref.ref_member(member, nil)
	else
	  ref = type_ref
      end
      text = nil
      @current_comment_block.add_inline(LinkTag.new(lineno, ref, text))
    end

    def end_see
      # TODO: if there was body-text in the tag, add it to the link
      
      @comment_data.add_block(@current_comment_block)
      @current_comment_block = nil
      pop_text_handler
    end
    def start_link(type, kind, member)
      lineno = 0
      type_ref = ref_to(type) if type
      case kind
	when :method
	  ref = type_ref.ref_method(member, nil)
	when :field
	  ref = type_ref.ref_member(member, nil)
	else
	  ref = type_ref
      end
      text = nil
      link_tag = LinkTag.new(lineno, ref, text)
      push_text_handler(LinkBlockTextHandler.new(link_tag))
      @current_comment_block.add_inline(link_tag)
    end
    def end_link
      pop_text_handler
    end
    def implements(interface)
      @current_type.add_interface(ref_to(interface))
    end
    def start_constructor; end
    def end_constructor; end
    def start_method(name, visibility, static)
      access = ASAccess.new(visibility, static)
      @current_api_element = @current_method = ASMethod.new(@current_type, access, name)
    end
    def end_method
      @current_type.add_method(@current_method)
      @current_api_element = @current_method = nil
    end
    def start_param(name, type)
      @current_comment_block = @current_param_block = ParamBlockTag.new
      @current_comment_block.param_name = name
      @current_arg = ASArg.new(name)
      @current_arg.arg_type = ref_to(type) if type
      push_text_handler(CommentBlockTextHandler.new(@current_comment_block))
    end
    def end_param
      unless @current_param_block.inlines.empty?
	@current_method.comment ||= CommentData.new
	@current_method.comment.add_block(@current_param_block)
      end
      @current_method.add_arg(@current_arg)
      @current_arg = nil
      @current_comment_block = nil
      pop_text_handler
    end
    def start_return(type)
      @current_comment_block = @current_return_block = ReturnBlockTag.new
      @current_method.return_type = ref_to(type) if type
      push_text_handler(CommentBlockTextHandler.new(@current_comment_block))
    end
    def end_return
      unless @current_return_block.inlines.empty?
	@current_method.comment ||= CommentData.new
	@current_method.comment.add_block(@current_return_block)
      end
      @current_comment_block = @current_return_block = nil
      pop_text_handler
    end
    def start_field(name, type, visibility, static)
      access = ASAccess.new(visibility, static)
      @current_api_element = @current_field = ASExplicitField.new(@current_type, access, name)
      @current_field.field_type = ref_to(type) if type
    end
    def end_field
      @current_type.add_field(@current_field)
      @current_api_element = @current_field = nil
    end
    def start_exception(type)
      @current_comment_block = @current_exception = ThrowsBlockTag.new
      @current_exception.exception_type = ref_to(type)
      push_text_handler(CommentBlockTextHandler.new(@current_comment_block))
    end
    def end_exception
      @current_method.comment.add_block(@current_exception)
      pop_text_handler
    end
    def start_code
      lineno = 0
      text = nil
      code_tag = CodeTag.new(lineno, text)
      # bit of a hack using LinkBlockTextHandler for CodeTag too, but CodeTag
      # and LinkTag both have the relevant #text attribute,
      push_text_handler(LinkBlockTextHandler.new(code_tag))
      @current_comment_block.add_inline(code_tag)
    end
    def end_code
      pop_text_handler
    end

    private

    def ref_to(name)
      @current_type.type_namespace.ref_to(name)
    end
  end  # class DeserializerAPIListner

end

# vim:sw=2:sts=2
