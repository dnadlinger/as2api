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
