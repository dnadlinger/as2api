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
require 'parse/doccomment_lexer'
require 'stringio'

class TC_DocComemntLexer < Test::Unit::TestCase

  include ActionScript::ParseDoc

  def test_stars
    assert_lex_to("*", StarsToken.new("*", 1))
    assert_lex_to("**", StarsToken.new("**", 1))
    assert_lex_to(" *", StarsToken.new(" *", 1))
    assert_lex_to(" \t**", StarsToken.new(" \t**", 1))
  end

  def test_braces
    assert_lex_to("{", LBraceToken.new(1))
    assert_lex_to("}", RBraceToken.new(1))
  end

  def test_inline_tag
    assert_lex_to("{@", LBraceToken.new(1),
                        WordToken.new("@", 1))
    assert_lex_to("{@ ", LBraceToken.new(1),
                         WordToken.new("@", 1),
			 WhitespaceToken.new(" ", 1))
    assert_lex_to("{@f", InlineAtTagToken.new("f", 1))
  end

  def test_para_tag
    assert_lex_to("@ ", WordToken.new("@", 1),
                        WhitespaceToken.new(" ", 1))
    assert_lex_to("@f", ParaAtTagToken.new("f", 1))
    # parser would catch that this is not a valid place for a para-tag, and
    # treat as normal word,
    assert_lex_to("{ @f", LBraceToken.new(1),
			  WhitespaceToken.new(" ", 1),
                          ParaAtTagToken.new("f", 1))
  end

 private

  def assert_lex_to(text, *tokens)
    input = StringIO.new(text)
    lex = DocCommentLexer.new(input)
    tokens.each do |expected|
      tok = lex.get_next
      assert_equal(expected.class, tok.class)
      assert_equal(expected.body, tok.body)
    end
    assert_nil(lex.get_next)
  end

end
