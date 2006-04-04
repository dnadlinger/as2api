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

require 'test/unit'
require 'stringio'
require 'output/diff/api_serializer'
require 'output/diff/api_deserializer'
require 'mock_api'
require 'api_loader'

class TC_APISerializer < Test::Unit::TestCase
  def test_simple
    io = StringIO.new
    api_name = "Mock API"
    api_version = "1.0"
    ser = APISerializer.new(io, api_name, api_version)
    expected_type_aggregator = MockAPI.create
    ser.serialize_api(expected_type_aggregator)
    io.rewind
    deser = APIDeserializer.new(io)
    result_type_aggregator, actual_api_name, actual_ver = deser.deserialize_api
    assert_equal(api_name, actual_api_name)
    assert_equal(api_version, actual_ver)
    assert_api_match(expected_type_aggregator, result_type_aggregator)
  end

  def assert_api_match(expected, actual)
    expected_types = expected.types
    actual_types = actual.types
    assert_equal(expected_types.length, actual_types.length, "Number of types differ")
    index = 0
    expected_types.each do |expected_type|
      assert_type_match(expected_type, actual_types[index])
      index += 1
    end
  end

  def assert_type_match(expected_type, actual_type)
    assert_equal(expected_type.qualified_name, actual_type.qualified_name)
    assert_comments_equal(expected_type.comment, actual_type.comment)
    if expected_type.respond_to?(:interfaces)
      assert_equal(expected_type.interfaces.map{|i|i.name}, actual_type.interfaces.map{|i|i.name})
    end
    assert_members_equal(expected_type, actual_type)
  end

  def assert_members_equal(expected_type, actual_type)
    assert_methods_equal(expected_type, actual_type)
    assert_fields_equal(expected_type, actual_type) if expected_type.respond_to?(:fields)
  end

  def assert_methods_equal(expected_type, actual_type)
    expected_methods = expected_type.methods
    actual_methods = actual_type.methods
    assert_same(expected_methods.length, actual_methods.length)
    expected_methods.each_with_index do |expected_method, index|
      assert_method_equal(expected_method, actual_methods[index])
    end
  end

  def assert_method_equal(expected_method, actual_method)
    assert_equal(expected_method.name, actual_method.name)
    assert_equal(expected_method.access, actual_method.access)
    assert_comments_equal(expected_method.comment, actual_method.comment)
  end

  def assert_fields_equal(expected_type, actual_type)
    expected_fields = expected_type.fields
    actual_fields = actual_type.fields
    assert_same(expected_fields.length, actual_fields.length)
    expected_fields.each_with_index do |expected_field, index|
      assert_field_equal(expected_field, actual_fields[index])
    end
  end

  def assert_field_equal(expected_field, actual_field)
    assert_equal(expected_field.name, actual_field.name)
    assert_access_equal(expected_field.access, actual_field.access)
    # cheat with line numbers, since these are not available in the xml dump
    if actual_field.field_type
      actual_field.field_type.lineno = expected_field.field_type.lineno
    end
    assert_equal(expected_field.field_type, actual_field.field_type)
    assert_comments_equal(expected_field.comment, actual_field.comment)
  end

  def assert_access_equal(expected_access, actual_access)
  end

  def assert_comments_equal(expected_comment_data, actual_comment_data)
    index = 0
    return if expected_comment_data.nil? && actual_comment_data.nil?
    assert_equal(expected_comment_data.nil?, actual_comment_data.nil?,
                 actual_comment_data.inspect)
    assert_not_nil(actual_comment_data, "Comment missing")
    expected_comment_data.each_block do |expected_block|
      assert_comment_block_equal(expected_block, actual_comment_data[index])
      index += 1
    end
  end

  def assert_comment_block_equal(expected_block, actual_block)
    assert_same(expected_block.class, actual_block.class, "#{expected_block.inspect} expected, but found #{actual_block.inspect}")
    assert_equal(expected_block.inlines.length, actual_block.inlines.length,
                 "Number of inlines differ in #{expected_block.class.name}")
    # cheat, and copy the expected line numbers into the actual inlines,
    # as the XML format doesn't carry the line numbers from the orig src
    expected_block.inlines.each_with_index do |expected_inline, index|
      actual_inline = actual_block.inlines[index]
      actual_inline.lineno = expected_inline.lineno if expected_inline.respond_to?(:lineno)
      if expected_inline.respond_to?(:target_ref) && expected_inline.target_ref && expected_inline.target_ref.respond_to?(:lineno)
	actual_inline.target_ref.lineno = expected_inline.target_ref.lineno
      end
    end
    assert_equal(expected_block, actual_block)
  end
end

# vim:sw=2:sts=2
