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

class TC_ActionScriptLexer < Test::Unit::TestCase

  include ActionScript::Parse

  def test_lex_error
    begin
      assert_lex_to("@")
      flunk("should be exception on invalid input")
    rescue
    end
  end

  def test_simple_string
    assert_lex_to("'test'", StringToken.new("test", 1))
    assert_lex_to("\"test\"", StringToken.new("test", 1))
    assert_lex_to("\"'\"", StringToken.new("'", 1))
    assert_lex_to('"\\"\"', StringToken.new('"', 1))
  end

  def test_identfier
    assert_lex_to("foo", IdentifierToken.new("foo", 1))
    # check keyword at start of identifier doesn't confuse lexer
    assert_lex_to("getfoo", IdentifierToken.new("getfoo", 1))
    assert_lex_to("BAR", IdentifierToken.new("BAR", 1))
    # 'dollar' and underscore are allowed
    assert_lex_to("$foo", IdentifierToken.new("$foo", 1))
    assert_lex_to("bar$", IdentifierToken.new("bar$", 1))
    assert_lex_to("_x", IdentifierToken.new("_x", 1))
    assert_lex_to("z_", IdentifierToken.new("z_", 1))
  end

  def test_number
    assert_lex_to("1", NumberToken.new("1", 1))
  end

  def test_single_line_comment
    assert_lex_to("// foo ", SingleLineCommentToken.new(" foo ", 1))
    # 'single line' comments shouldn't eat the whole body of a Mac-format file
    assert_lex_to("//foo\r", SingleLineCommentToken.new("foo", 1),
                             WhitespaceToken.new("\r", 1))
  end

  def test_multiline_comment
    assert_lex_to("/* hide!/* */", MultiLineCommentToken.new(" hide!/* ", 1))
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

  def assert_lex_to(text, *tokens)
    input = StrIO.new(text)
    lex = ASLexer.new(input)
    tokens.each do |expected|
      tok = lex.get_next
      assert_equal(expected.class, tok.class)
      assert_equal(expected.body, tok.body)
    end
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
