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
require 'localisation/xliff/xliff_writer'
require 'localisation/xliff/xliff_doc_utils'
require 'output/xml/xml_formatter'

class XLIFFGenerator
  include XLIFFWriter

  def initialize(xml_writer, source_lang, target_lang)
    @io = xml_writer
    @source_lang = source_lang
    @target_lang = target_lang
  end


  def generate_template_xliff(type_aggregator)
    xliff_xliff("version"=>"1.0") do
      type_aggregator.each_type do |astype|
        generate_file_template(astype);
      end
    end
  end

  def generate_file_template(astype)
    xliff_file("original"=>astype.input_filename,
         "source-language"=>@source_lang,
	 "target-language"=>@target_lang,
	 "datatype"=>"plaintext",
	 "xml:space"=>"preserve") do
      xliff_header do
      end
      xliff_body do
        gen_type_trans_units(astype) if astype.comment
	gen_member_trans_units(astype)
      end
    end
  end

  def trans_unit(id, *contexts)
    xliff_trans_unit("id"=>id) do
      xliff_source do
	yield
      end
      xliff_target do
      end
      unless contexts.empty?
	simple_context_group("api", *contexts)
      end
    end
  end

  def simple_context_group(name, *contexts)
    xliff_context_group("name"=>name) do
      until contexts.empty?
	context_type, value, *contexts = contexts
	xliff_context("context-type"=>context_type) do
	  pcdata(value)
	end
      end
    end
  end

  def gen_member_trans_units(astype)
    if astype.respond_to?(:each_field)
      astype.each_field do |asfield|
	gen_field_comment(asfield) if asfield.comment
      end
    end
    astype.each_method do |asmethod|
      gen_method_comment(asmethod) if asmethod.comment
    end
  end

  def gen_method_comment(asmethod)
    @see_index = 0
    asmethod.comment.each_block do |block|
      send("gen_method_block_#{block.class.name}", asmethod, block)
      @see_index += 1 if block.is_a?(SeeBlockTag)
    end
    @see_index = nil
  end

  def gen_field_comment(asfield)
      asfield.comment.each_block do |block|
	send("gen_field_block_#{block.class.name}", asfield, block)
      end
  end

  def gen_type_trans_units(astype)
    @see_index = 0
    astype.comment.each_block do |block|
      send("gen_type_block_#{block.class.name}", astype, block)
      @see_index += 1 if block.is_a?(SeeBlockTag)
    end
    @see_index = nil
  end

  def gen_type_block_BlockTag(astype, block)
    kind = if astype.is_a?(ASClass)
      "class"
    else
      "interface"
    end
    trans_unit(XliffIds.id_for_type_description(astype),
	       "element", kind,
               "type", astype.qualified_name) do
      gen_inlines(block)
    end
  end

  def gen_method_block_BlockTag(asmethod, block)
    trans_unit(XliffIds.id_for_method_description(asmethod),
	       "element", "method",
               "type", asmethod.containing_type.qualified_name,
               "method", asmethod.name) do
      gen_inlines(block)
    end
  end

  def gen_field_block_BlockTag(asfield, block)
    trans_unit(XliffIds.id_for_field_description(asfield),
	       "element", "field",
               "type", asfield.containing_type.qualified_name,
               "field", asfield.name) do
      gen_inlines(block)
    end
  end

  def gen_method_block_ParamBlockTag(asmethod, block)
    trans_unit(XliffIds.id_for_parameter_description(asmethod,block.param_name),
	       "element", "parameter",
               "type", asmethod.containing_type.qualified_name,
               "method", asmethod.name,
               "parameter", block.param_name) do
      gen_inlines(block)
    end
  end

  def gen_method_block_ReturnBlockTag(asmethod, block)
    trans_unit(XliffIds.id_for_method_return(asmethod),
	       "element", "return",
               "type", asmethod.containing_type.qualified_name,
               "method", asmethod.name) do
      gen_inlines(block)
    end
  end

  def gen_method_block_ThrowsBlockTag(asmethod, block)
    trans_unit(XliffIds.id_for_throws_description(asmethod, block.exception_type.resolved_type),
	       "element", "throws",
               "type", asmethod.containing_type.qualified_name,
               "method", asmethod.name,
               "throws", block.exception_type.resolved_type.qualified_name) do
      gen_inlines(block)
    end
  end

  def gen_method_block_SeeBlockTag(asmethod, block)
    trans_unit(XliffIds.id_for_method_see(asmethod, @see_index),
	       "element", "see",
               "type", asmethod.containing_type.qualified_name,
               "method", asmethod.name) do
      gen_inlines(block)
    end
  end

  def gen_type_block_SeeBlockTag(astype, block)
    trans_unit(XliffIds.id_for_type_see(astype, @see_index),
	       "element", "see",
               "type", astype.qualified_name) do
      gen_inlines(block)
    end
  end

  def gen_inlines(block)
    index = 0
    block.each_inline do |inline|
      if index==0 && inline.is_a?(String)
	inline = inline.lstrip
      end
      if index==block.inlines.length-1 && inline.is_a?(String)
	inline = inline.rstrip
      end
      gen_inline(inline)
      index += 1
    end
  end

  def gen_inline(inline)
    if inline.is_a?(String)
      pcdata(inline)
    else
      send("gen_inline_#{inline.class.name}", inline)
    end
  end

  def gen_inline_CodeTag(inline)
    xliff_ph("id"=>"code") do
      pcdata(inline.text)
    end
  end

  def gen_inline_LinkTag(inline)
    xliff_ph("id"=>"link") do
      if inline.target
	pcdata(inline.target.local_name)
      end
      if inline.member
	pcdata("#")
	pcdata(inline.member)
      end
      if inline.text && inline.text != ""
	xliff_sub("id"=>"link-text") do
	  pcdata(inline.text)
	end
      end
    end
  end
end

def generate_xliff(conf, type_aggregator)
  encoding = "UTF-8"
  File.open(conf.xliff_export, "w") do |io|
    xml = XMLWriter.new(io)
    xml.pi("xml version=\"1.0\" encoding=\"#{encoding}\"")
    xml.pcdata("\n")
    xml.doctype("xliff", "PUBLIC",
                "-//XLIFF//DTD XLIFF//EN",
	       "http://www.oasis-open.org/committees/xliff/documents/xliff.dtd")
    format = XMLFormatter.new(xml)
    format.inlines [ "source", "target", "context", "ph", "sub", "it", "bpt", "ept", "g", "x", "bx", "ex", "mrk" ]
    gen = XLIFFGenerator.new(format, conf.source_lang, conf.target_lang)
    gen.generate_template_xliff(type_aggregator)
  end
end

# vim:softtabstop=2:shiftwidth=2
