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
require 'parse/aslexer'
require 'parse/parser'
require 'stringio'

class TC_ActionScriptParser < Test::Unit::TestCase

  include ActionScript::Parse

  def test_compilation_unit
    simple_parse("class Foo {}") do |parse|
      parse.parse_compilation_unit
    end
  end

  def test_imports_and_attributes
    simple_parse("[foo=bar]\nimport foo;[bar=foo]\nclass Foo {}") do |parse|
      parse.parse_compilation_unit
    end
  end

  def test_access_modifier
    simple_parse("") do |parse|
      access = parse.parse_access_modifier
      assert(!access.is_static)
      assert_nil(access.visibility)
    end
    simple_parse("public") do |parse|
      access = parse.parse_access_modifier
      assert(!access.is_static)
      assert_instance_of(PublicToken, access.visibility)
    end
    simple_parse("private") do |parse|
      access = parse.parse_access_modifier
      assert(!access.is_static)
      assert_instance_of(PrivateToken, access.visibility)
    end
    simple_parse("static") do |parse|
      access = parse.parse_access_modifier
      assert(access.is_static)
    end
    simple_parse("public static") do |parse|
      access = parse.parse_access_modifier
      assert(access.is_static)
      assert_instance_of(PublicToken, access.visibility)
    end
    simple_parse("private static") do |parse|
      access = parse.parse_access_modifier
      assert(access.is_static)
      assert_instance_of(PrivateToken, access.visibility)
    end
  end

  def test_parse_member
    simple_parse("private static var foo;") do |parse|
      access = parse.parse_class_member
    end
    simple_parse("private static function foo() { }") do |parse|
      access = parse.parse_class_member
    end
    simple_parse("function get foo() { }") do |parse|
      access = parse.parse_class_member
    end
    simple_parse("function get() { }") do |parse|
      access = parse.parse_class_member
    end
  end

  def test_parse_multi_field
    simple_parse("var foo:String,bar:Number;}") do |parse|
      parse.parse_class_member_list
      # consume '}' -- hack around private expect() by using send()
      parse.send(:expect, ActionScript::Parse::RBraceToken)
    end
  end

 private
  def simple_parse(text)
    input = StringIO.new(text)
    lex = SkipASLexer.new(ASLexer.new(input))
    parse = ASParser.new(lex)
    parse.handler = ASHandler.new
    yield parse
    assert_nil(lex.get_next)
  end
end
