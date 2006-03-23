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
require 'parse/doccomment_parser'
require 'stringio'

class MyDocCommentHandler < ActionScript::ParseDoc::DocCommentHandler
  def initialize; @collected_text=""; end
  attr_reader :collected_text
  def text(text); @collected_text<<text.to_s; end
end

class TC_DocCommentParser < Test::Unit::TestCase

  include ActionScript::ParseDoc

  def test_parse_comment
    simple_parse("", :parse_comment)
    simple_parse("*", :parse_comment)
    simple_parse(" *foo\n * foo\n", :parse_comment, "foo\n foo\n")

    comment_text = <<HERE
some test {text @param foo

more {@foobar}

@param asia is clever {@link   here }

@throws java.lang.RuntimeException blah blah
	blah blah

@see other
HERE

    simple_parse(comment_text, :parse_comment, "some test {text @param foo\n\nmore \n\n asia is clever    here \n\n java.lang.RuntimeException blah blah\n	blah blah\n\n other\n")
  end

  def test_parse_para_tag
    simple_parse("@param foo", :parse_line, " foo")
  end

  def test_parse_inline_tag
    simple_parse("{@link foo}", :parse_inline_tag, " foo")
    simple_parse("{@link\nfoo}", :parse_inline_tag, "\nfoo")
    # check initial stars are stripped inside inline-tags,
    simple_parse("{@link\n * foo}", :parse_inline_tag, "\n foo")
    # stars should be stripped in an inline-tag's nested braces too,
    simple_parse("{@code for(;;){\n * foo}}", :parse_inline_tag, " for(;;){\n foo}")
  end

  def test_parse_brace_pair
    txt = "{{}{{}}}"
    simple_parse(txt, :parse_brace_pair, txt)
  end

 private
  def simple_parse(text, method, expected_text="")
    input = StringIO.new(text)
    lex = DocCommentLexer.new(input)
    parse = DocCommentParser.new(lex)
    handler = MyDocCommentHandler.new
    parse.handler = handler
    parse.method(method).call
    assert_nil(lex.get_next)
    assert_equal(expected_text, handler.collected_text)
  end
end
