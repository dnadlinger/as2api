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


require 'parse/lexer'

module ActionScript
module ParseDoc

class WhitespaceToken < ActionScript::Parse::ASToken
end

class EndOfLineToken < ActionScript::Parse::ASToken
end

class StarsToken < ActionScript::Parse::ASToken
end

class ParaAtTagToken < ActionScript::Parse::ASToken
  def to_s
    "@#{@body}"
  end
end

class InlineAtTagToken < ActionScript::Parse::ASToken
  def to_s
    "{@#{@body}"
  end
end

class WordToken < ActionScript::Parse::ASToken
end

class DocCommentLexer < ActionScript::Parse::AbstractLexer
  def lex_simple_token(class_sym, match, io)
    ActionScript::ParseDoc.const_get(class_sym).new(io.lineno-1)
  end

  def lex_simplebody_token(class_sym, match, io)
    ActionScript::ParseDoc.const_get(class_sym).new(match[0], io.lineno-1)
  end

  def lex_simplecapture_token(class_sym, match, io)
    ActionScript::ParseDoc.const_get(class_sym).new(match[1], io.lineno-1)
  end
end

END_OF_LINE = "\r\n|\r|\n"
DOC_WHITESPACE = "[ \t\f]"
AT_INLINE_TAG = "\\{@([^ \t\r\n\f}{]+)"
AT_PARA_TAG = "@([^ \t\r\n\f]+)"
WHITESPACE_THEN_STARS = "[ \t]*\\*+"
WORD = "[^ \t\f\n\r}{]+"

def self.build_doc_lexer
  builder = ActionScript::Parse::LexerBuilder.new(ActionScript::ParseDoc)

  builder.add_match(WHITESPACE_THEN_STARS, :lex_simplebody_token, :StarsToken)
  builder.add_match(DOC_WHITESPACE, :lex_simplebody_token, :WhitespaceToken)
  builder.add_match(END_OF_LINE, :lex_simplebody_token, :EndOfLineToken)

  builder.add_match(AT_INLINE_TAG, :lex_simplecapture_token, :InlineAtTagToken)
  builder.add_match(AT_PARA_TAG, :lex_simplecapture_token, :ParaAtTagToken)

  builder.make_punctuation_token(:LBrace, "{")
  builder.make_punctuation_token(:RBrace, "}")

  builder.add_match(WORD, :lex_simplebody_token, :WordToken)

  builder.build_lexer(DocCommentLexer)
end

build_doc_lexer


end
end
