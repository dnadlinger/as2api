require 'test/unit'
require 'parse/lexer'
require 'parse/parser'

class TC_ActionScriptParser < Test::Unit::TestCase

  include ActionScript::Parse

  def test_compilation_unit
    simple_parse("class Foo {}") do |parse|
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
  end

 private
  def simple_parse(text)
    input = StrIO.new(text)
    lex = SkipASLexer.new(ASLexer.new(input))
    parse = ASParser.new(lex)
    parse.handler = ASHandler.new
    yield parse
    assert_nil(lex.get_next)
  end
end

# Simple IO-like object the readsfrom a String, rather than a file
# TODO: handle multiple lines
class StrIO
  def initialize(data)
    @data = data
  end

  def readline
    dat = @data
    @data = nil
    dat
  end

  def eof?
    @data.nil?
  end

  def lineno
    1
  end
end
