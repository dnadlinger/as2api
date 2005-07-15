
require 'parse/lexer'

module ActionScript
module Parse

class DocWhitespaceToken < ASToken
end

class EndOfLineToken < ASToken
end

class StarsToken < ASToken
end

class ParaAtTagToken < ASToken
  def to_s
    "@#{@body}"
  end
end

class InlineAtTagToken < ASToken
  def to_s
    "{@#{@body}"
  end
end

class WordToken < ASToken
end

class DocCommentLexer < AbstractLexer
  def lex_simple_token(class_sym, match, io)
    ActionScript::Parse.const_get(class_sym).new(io.lineno)
  end

  def lex_simplebody_token(class_sym, match, io)
    ActionScript::Parse.const_get(class_sym).new(match[0], io.lineno)
  end

  def lex_simplecapture_token(class_sym, match, io)
    ActionScript::Parse.const_get(class_sym).new(match[1], io.lineno)
  end
end

END_OF_LINE = "\r\n|\r|\n"
DOC_WHITESPACE = "[ \t\f]"
AT_INLINE_TAG = "\\{@([^ \t\r\n\f}{]+)"
AT_PARA_TAG = "@([^ \t\r\n\f]+)"
WHITESPACE_THEN_STARS = "[ \t]*\\*+"
WORD = "[^ \t\f\n\r}{]+"

def self.build_doc_lexer
  builder = LexerBuilder.new

  builder.add_match(WHITESPACE_THEN_STARS, :lex_simplebody_token, :StarsToken)
  builder.add_match(DOC_WHITESPACE, :lex_simplebody_token, :DocWhitespaceToken)
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
