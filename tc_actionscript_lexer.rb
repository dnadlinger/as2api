require 'test/unit'
require 'parse/lexer'

class TC_ActionScriptLexer < Test::Unit::TestCase

  include ActionScript::Parse

  def test_simple_string
    simple_lex("'test'") do |tok|
      assert_instance_of(StringToken, tok)
      assert_equal("test", tok.body)
    end
    simple_lex("\"test\"") do |tok|
      assert_instance_of(StringToken, tok)
      assert_equal("test", tok.body)
    end
    simple_lex("\"'\"") do |tok|
      assert_instance_of(StringToken, tok)
      assert_equal("'", tok.body)
    end
    simple_lex('"\\"\"') do |tok|
      assert_instance_of(StringToken, tok)
      assert_equal('"', tok.body)
    end
  end

  def test_identfier
    simple_lex("foo") do |tok|
      assert_instance_of(IdentifierToken, tok)
      assert_equal("foo", tok.body)
    end
    # check keyword at start of identifier doesn't confuse lexer
    simple_lex("getfoo") do |tok|
      assert_instance_of(IdentifierToken, tok)
      assert_equal("getfoo", tok.body)
    end
    simple_lex("BAR") do |tok|
      assert_instance_of(IdentifierToken, tok)
      assert_equal("BAR", tok.body)
    end
  end

  def test_number
    simple_lex("1") do |tok|
      assert_instance_of(NumberToken, tok)
      assert_equal("1", tok.body)
    end
  end

  def test_single_line_comment
    simple_lex("// foo ") do |tok|
      assert_instance_of(SingleLineCommentToken, tok)
      assert_equal(" foo ", tok.body)
    end
  end

  def test_multiline_comment
    simple_lex("/* hide!/* */") do |tok|
      assert_instance_of(MultiLineCommentToken, tok)
      assert_equal(" hide!/* ", tok.body)
    end
  end

  def test_comma; assert_simple_token(",", CommaToken) end
  def test_lbrace; assert_simple_token("{", LBraceToken) end
  def test_rbrace; assert_simple_token("}", RBraceToken) end
  def test_colon; assert_simple_token(":", ColonToken) end
  def test_semicolon; assert_simple_token(";", SemicolonToken) end
  def test_lbracket; assert_simple_token("[", LBracketToken) end
  def test_rbracket; assert_simple_token("]", RBracketToken) end
  def test_rparen; assert_simple_token(")", RParenToken) end
  def test_equals; assert_simple_token("=", AssignToken) end
  def test_greater; assert_simple_token(">", GreaterToken) end
  def test_divide; assert_simple_token("/", DivideToken) end
  def test_divide_assign; assert_simple_token("/=", DivideAssignToken) end
  def test_dynamic; assert_simple_token("dynamic", DynamicToken) end
  def test_whitespace; assert_simple_token(" \t\n", WhitespaceToken) end


#  def test_multiline_string
#    simple_lex("'test
#test
#test'") do |tok|
#      assert_instance_of(StringToken, tok)
#      assert_equal("test
#test
#test", tok.body)
#    end
#  end

 private
  def simple_lex(text)
    input = StrIO.new(text)
    lex = ASLexer.new(input)
    yield lex.get_next
    assert_nil(lex.get_next)
  end

  def assert_simple_token(text, token)
    simple_lex(text) do |tok|
      assert_instance_of(token, tok)
    end
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
