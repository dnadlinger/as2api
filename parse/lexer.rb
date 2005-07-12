
require 'strscan'

module ActionScript
module Parse

# TODO Create an EOFToken (so that we can report its line number)

class ASToken
  def initialize(body, lineno)
    @body = body
    @lineno = lineno
  end
  def body
    @body
  end
  def lineno
    @lineno
  end
  def to_s
    @body
  end
end

class CommentToken < ASToken
end

class NumberToken < CommentToken
end

class SingleLineCommentToken < CommentToken
  def to_s
    "//#{@body}"
  end
end

class MultiLineCommentToken < CommentToken
  def to_s
    "/*#{@body}*/"
  end
end

class WhitespaceToken < ASToken
end

class IdentifierToken < ASToken
end

class StringToken < ASToken
  def initialize(body, lineno)
    @body = unescape(body)
    @lineno = lineno
  end

  def to_s
    "\"#{escape(@body)}\""
  end

  def escape(text)
    text.gsub(/./m) do
      case $&
        when "\\" then "\\\\"
        when "\"" then "\\\""
	when "\n" then "\\n"
	when "\t" then "\\t"
        else $&
      end
    end
  end

  def unescape(text)
    escape = false
    text.gsub(/./) do
      if escape
        escape = false
        case $&
          when "\\" then "\\"
          when "n" then "\n"
          when "t" then "\t"
          else $&
        end
      else
        case $&
	  when "\\" then escape=true; ""
	  else $&
	end
      end
    end
  end
end

# "get" and "set" where initially included in this list, since they are used
# as modifiers to function declarations.  The are also allowed to appear as
# identifiers, unfortunately, so we treat them as such, and have the parser
# make special checks on the identifier body.
Keywords = [
  "as",
  "break",
  "case",
  "catch",
  "class",
  "const",
  "continue",
  "default",
  "dynamic",     # non-ECMA
  "delete",
  "do",
  "else",
  "extends",
  "false",
  "finally",
  "for",
  "function",
  "if",
  "implements",  # reserved, but unused in ECMA
  "import",
  "in",
  "instanceof",
  "interface",   # reserved, but unused in ECMA
  "intrinsic",   # non-ECMA
#  "is",         # not a keyword in AS
#  "namespace",  # not a keyword in AS
  "new",
  "null",
  "package",
  "private",
  "public",
  "return",
  "static",      # non-ECMA
  "super",
  "switch",
  "this",
  "throw",
  "true",
  "try",
  "typeof",
  "use",
  "var",
  "void",
  "while",
  "with"
]

Reserved = [
  "abstract",
  "debugger",
  "enum",
  "export",
  "goto",
  "native",
  "protected",
  "synchronized",
  "throws",
  "transient",
  "volatile"
]

Punctuation = [
  [:DivideAssign,         "/="],
  [:Divide,               "/"],
  [:BitNot,               "~"],
  [:RBrace,               "}"],
  [:OrAssign,             "||="],
  [:Or,                   "||"],
  [:BitOrAssign,          "|="],
  [:BitOr,                "|"],
  [:LBrace,               "{"],
  [:XOrAssign,            "^^="],
  [:XOr,                  "^^"],
  [:BitXOrAssign,         "^="],
  [:BitXOr,               "^"],
  [:RBracket,             "]"],
  [:LBracket,             "["],
  [:Hook,                 "?"],
  [:RShiftUnsignedAssign, ">>>="],
  [:RShiftUnsigned,       ">>>"],
  [:RShiftAssign,         ">>="],
  [:RShift,               ">>"],
  [:GreaterEquals,        ">="],
  [:Greater,              ">"],
  [:Same,                 "==="],
  [:Equals,               "=="],
  [:Assign,               "="],
  [:LessEquals,           "<="],
  [:LShiftAssign,         "<<="],
  [:LShift,               "<<"],
  [:Less,                 "<"],
  [:Semicolon,            ";"],
  [:Member,               "::"],
  [:Colon,                ":"],
  [:Ellipsis,             "..."],
  [:Dot,                  "."],
  [:MinusAssign,          "-="],
  [:Decrement,            "--"],
  [:Minus,                "-"],
  [:Comma,                ","],
  [:PlusAssign,           "+="],
  [:Increment,            "++"],
  [:Plus,                 "+"],
  [:StarAssign,           "*="],
  [:Star,                 "*"],
  [:RParen,               ")"],
  [:LParen,               "("],
  [:BitAndAssign,         "&="],
  [:AndAssign,            "&&="],
  [:And,                  "&&"],
  [:BitAnd,               "&"],
  [:ModuloAssign,         "%="],
  [:Modulo,               "%"],
  [:BangSame,             "!=="],
  [:BangEquals,           "!="],
  [:Bang,                 "!"]
]

# This is a Lexer for the tokens of ActionScript 2.0.
class ASLexer
  # This is a naive lexer implementation that considers input line-by-line,
  # with special cases to handle multiline tokens (strings, comments).
  # spacial care must be taken to declaire tokens in the 'correct' order (as
  # the fist match wins), and to cope with keyword/identifier ambiguity
  # (keywords have '\b' regexp-lookahead appended)

  @@matches = []

  def initialize(io)
    @io = io
    @tokens = Array.new
    @eof = false
  end

  def get_next
    nextt
  end

  def peek_next
    check_fill()
    @tokens[0]
  end

  protected

  def nextt
    check_fill()
    @tokens.shift
  end

  private

  def ASLexer.make_match(match)
    match.gsub("/", "\\/").gsub("\n", "\\n")
  end

  h =		"[0-9a-fA-F]"
  nl =		"\\n|\\r\\n|\\r|\\f"
  nonascii =	"[\\200-\\377]"
  unicode =	"\\\\#{h}{1,6}[ \\t\\r\\n\\f]?"
  escape =	"(?:#{unicode}|\\\\[ -~\\200-\\377])"
  nmstart =	"(?:[a-zA-Z_$]|#{nonascii}|#{escape})"
  nmchar =	"(?:[a-zA-Z0-9_$]|#{nonascii}|#{escape})"
  SINGLE_LINE_COMMENT = "//([^\n\r]*)"
  OMULTI_LINE_COMMENT = "/\\*"
  CMULTI_LINE_COMMENT = "\\*/"
  STRING_START1 = "'"
  STRING_END1 = "((?:(?:\\\\')|[\\t !\#$%&(-~]|#{nl}|\"|#{nonascii}|#{escape})*)\'"
  STRING_START2 = '"'
  STRING_END2 = "((?:(?:\\\\\")|[\\t !\#$%&(-~]|#{nl}|'|#{nonascii}|#{escape})*)\""
  WHITESPACE = "[ \t\r\n\f]+"


  ident =	"#{nmstart}#{nmchar}*"
#  name =	"#{nmchar}+"
  num	 =	"[0-9]+|[0-9]*\\.[0-9]+"
#  string =	"#{string1}|#{string2}"
  w =		"[ \t\r\n\f]*"


  def self.add_match(match, lex_meth_sym, tok_class_sym)
    @@matches << [make_match(match), lex_meth_sym, tok_class_sym]
  end

  def self.make_simple_token(name, value, match)
    class_name = "#{name}Token"
    the_class = Class.new(ASToken)
    the_class.class_eval <<-EOE
    def initialize(lineno)
      super("#{value}", lineno)
    end
    EOE
    ActionScript::Parse.const_set(class_name, the_class)

    add_match(match, :lex_simple_token, class_name.to_sym)
  end

  def lex_simple_token(class_sym, match, io)
    ActionScript::Parse.const_get(class_sym).new(io.lineno)
  end

  def self.make_keyword_token(name)
    make_simple_token(name.capitalize, name, "#{name}\\b")
  end

  # TODO: whitespace tokens don't span lines, which might not be the expected
  #       behaviour
  add_match(WHITESPACE, :lex_simplebody_token, :WhitespaceToken)

  def lex_simplebody_token(class_sym, match, io)
    ActionScript::Parse.const_get(class_sym).new(match[0], io.lineno)
  end

  add_match(SINGLE_LINE_COMMENT, :lex_singlelinecoomment_token, :SingleLineCommentToken)

  def lex_singlelinecoomment_token(class_sym, match, io)
    SingleLineCommentToken.new(match[1], io.lineno)
  end

  add_match(OMULTI_LINE_COMMENT, :lex_multilinecomment_token, :MultiLineCommentToken)

  def lex_multilinecomment_token(class_sym, match, io)
    lineno = io.lineno
    line = match.post_match
    comment = ''
    until line =~ /\*\//o
      comment << line
      line = io.readline;
    end
    comment << $`
    match.string = $'
    MultiLineCommentToken.new(comment, lineno)
  end

  Keywords.each do |keyword|
    make_keyword_token(keyword)
  end

  def self.make_punctuation_token(name, value)
    make_simple_token(name, value, Regexp.escape(value))
  end

  Punctuation.each do |punct|
    make_punctuation_token(*punct)
  end

  add_match(ident, :lex_simplebody_token, :IdentifierToken)

  add_match(STRING_START1, :lex_string1_token, :StringToken)

  def lex_string1_token(class_sym, match, io)
    lineno = io.lineno
    line = match.post_match
    str = ''
    until line =~ /#{STRING_END1}/o
      str << line
      line = io.readline;
      raise "#{lineno}:unexpected EOF in string" if line.nil?
    end
    str << $1
    match.string = $'
    StringToken.new(str, lineno)
  end

  add_match(STRING_START2, :lex_string2_token, :StringToken)

  def lex_string2_token(class_sym, match, io)
    lineno = io.lineno
    line = match.post_match
    str = ''
    until line =~ /#{STRING_END2}/o
      str << line
      line = io.readline;
      raise "#{lineno}:unexpected EOF in string" if line.nil?
    end
    str << $1
    match.string = $'
    StringToken.new(str, lineno)
  end

  add_match(num, :lex_simplebody_token, :NumberToken)

  def check_fill
    if @tokens.empty? && !@io.eof?
      fill()
    end
  end

  def self.build_lexer
    text = <<-EOS
      def fill
        line = StringScanner.new(@io.readline)
        until line.eos?
    EOS
    @@matches.each_with_index do |token_match, index|
      re, lex_method, tok_class = token_match
      text << "if line.scan(/#{re}/)\n"
      text << "  emit(#{lex_method.to_s}(:#{tok_class.to_s}, line, @io))\n"
      text << "  next\n"
      text << "end\n"
    end
    text << <<-EOS
          # no previous regexp matched,
          parse_error(line.rest)
        end
      end
    EOS
    class_eval(text)
  end

  self.build_lexer

  public
  def emit(token)
    @tokens << token
  end

  def parse_error(text)
    raise "#{@io.lineno}:no lexigraphic match for text starting '#{text}'"
  end
  def warn(message)
    $stderr.puts(message)
  end
end


class SkipASLexer
  def initialize(lexer)
    @lex = lexer
    @handler = nil
  end

  def handler=(handler)
    @handler = handler
  end

  def get_next
    while skip?(tok=@lex.get_next)
      notify(tok)
    end
    tok
  end

  def peek_next
    while skip?(tok=@lex.peek_next)
      notify(tok)
      @lex.get_next
    end
    tok
  end

  protected

  def skip?(tok)
    tok.is_a?(CommentToken) || tok.is_a?(WhitespaceToken)
  end

  def notify(tok)
    unless @handler.nil?
      @handler.comment(tok.body)
    end
  end
end

end # module Parse
end # module ActionScript
