
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
  "get",         # explicitly excluded from ECMA
  "if",
  "implements",  # reserved, but unused in ECMA
  "import",
  "in",
  "instanceof",
  "interface",   # reserved, but unused in ECMA
  "intrinsic",   # non-ECMA
  "is",
#  "namespace",
  "new",
  "null",
  "package",
  "private",
  "public",
  "return",
  "set",         # explicitly excluded from ECMA
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
    Regexp.new("\\A#{match}")
  end

  h =		"[0-9a-fA-F]"
  nl =		"\\n|\\r\\n|\\r|\\f"
  nonascii =	"[\\200-\\377]"
  unicode =	"\\\\#{h}{1,6}[ \\t\\r\\n\\f]?"
  escape =	"(?:#{unicode}|\\\\[ -~\\200-\\377])"
  nmstart =	"(?:[a-zA-Z_]|#{nonascii}|#{escape})"
  nmchar =	"(?:[a-zA-Z0-9_]|#{nonascii}|#{escape})"
  SINGLE_LINE_COMMENT = "//([^\n\r]*)(?:\r\n|\r|\n)?"
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


  def self.add_match(match)
    @@matches << [make_match(match), Proc.new]
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

    add_match(match) do |lex, match, io|
      lex.emit(ActionScript::Parse.const_get(class_name).new(io.lineno))
      match.post_match
    end
  end

  def self.make_keyword_token(name)
    make_simple_token(name.capitalize, name, "#{name}\\b")
  end

  add_match(WHITESPACE) do |lex, match, io|
    # TODO: whitespace tokens don't span lines, which might not be the expected
    #       behaviour
    lex.emit(WhitespaceToken.new(match[0], io.lineno))
    match.post_match
  end

  add_match(SINGLE_LINE_COMMENT) do |lex, match, io|
    lex.emit(SingleLineCommentToken.new(match[1], io.lineno))
    match.post_match
  end

  add_match(OMULTI_LINE_COMMENT) do |lex, match, io|
    lineno = io.lineno
    line = match.post_match
    comment = ''
    until line =~ /\*\//o
      comment << line
      line = io.readline;
    end
    comment << $`
    lex.emit(MultiLineCommentToken.new(comment, lineno))
    $'
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

  add_match(ident) do |lex, match, io|
    lex.emit(IdentifierToken.new(match[0], io.lineno))
    match.post_match
  end

  add_match(STRING_START1) do |lex, match, io|
    lineno = io.lineno
    line = match.post_match
    str = ''
    until line =~ /\A#{STRING_END1}/o
      str << line
      line = io.readline;
    end
    str << $1
    lex.emit(StringToken.new(str, lineno))
    $'
  end

  add_match(STRING_START2) do |lex, match, io|
    lineno = io.lineno
    line = match.post_match
    str = ''
    until line =~ /\A#{STRING_END2}/o
      str << line
      line = io.readline;
    end
    str << $1
    lex.emit(StringToken.new(str, lineno))
    $'
  end

  add_match(num) do |lex, match, io|
    lex.emit(NumberToken.new(match[0], io.lineno))
    match.post_match
  end

  def check_fill
    if @tokens.empty? && !@io.eof?
      fill()
    end
  end

  def fill
    line = @io.readline
    while line.size>0
      matched = false
      @@matches.each do |token_match|
	re, action = token_match
	match = re.match(line)
	if match
	  line = action.call(self, match, @io)
	  matched = true
	  break
	end
      end
      unless matched
        parse_error(line)
      end
    end
  end

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
