
module ActionScript
module Parse


class AccessModifier
  def initialize
    @visibility = nil
    @is_static = false
  end

  attr_accessor :visibility, :is_static
end

class Argument
  def initialize(name)
    @name = name
    @type = nil
  end

  attr_accessor :name, :type
end

class FunctionSignature
  attr_accessor :arguments, :return_type
end

class ASParser
  def initialize(lexer)
    @lex = lexer
    @handler = nil
  end

  def handler=(handler)
    @handler = handler
  end


  def parse_compilation_unit
    @handler.compilation_unit_start
    parse_imports
    parse_type_definition
    @handler.compilation_unit_end
  end


  def parse_imports
    while lookahead?(ImportToken)
      parse_import
    end
  end

  def parse_import
    expect(ImportToken)
    @handler.import(parse_class_or_package)
    expect(SemicolonToken)
  end

  def parse_class_or_package
    name = []
    name << expect(IdentifierToken)
    while lookahead?(DotToken)
      expect(DotToken)
      if lookahead?(IdentifierToken)
	name << expect(IdentifierToken)
      elsif lookahead?(StarToken)
        name << expect(StarToken)
	break
      else
	err("Expected <identifier> or <star>, but found #{@lex.peek_next.inspect}")
      end
    end
    name
  end

  def parse_type_definition
    if lookahead?(ClassToken)
      parse_class_definition
    elsif lookahead?(InterfaceToken)
      parse_interface_definition
    else
      err("Expected <class> or <interface>, but found #{@lex.peek_next.inspect}")
    end
  end

  def parse_class_definition
    dynamic = false
    speculate(DynamicToken) do
      dynamic = true
    end
    expect(ClassToken)
    name = parse_type_name
    super_name = nil
    speculate(ExtendsToken) do
      super_name = parse_type_name
    end
    interfaces = []
    speculate(ImplementsToken) do
      interfaces << parse_type_name
      while lookahead?(CommaToken)
        expect(CommaToken)
        interfaces << parse_type_name
      end
    end
    expect(LBraceToken)
    @handler.start_class(dynamic, name, super_name, interfaces)
    parse_class_member_list
    expect(RBraceToken)
    @handler.end_class
  end

  def parse_interface_definition
    raise "not implemented"
  end

  def parse_type_name
    name = []
    name << expect(IdentifierToken)
    while lookahead?(DotToken)
      expect(DotToken)
      name << expect(IdentifierToken)
    end
    return name
  end

  def parse_class_member_list
    until lookahead?(RBraceToken)
      parse_class_member
    end
  end

  def parse_class_member
    @handler.access_modifier(parse_access_modifier)
    if lookahead?(VarToken)
      parse_member_field
    elsif lookahead?(FunctionToken)
      parse_member_function
    else
      err("Expected <var> or <function> but found #{@lex.peek_next.inspect}")
    end
  end

  def parse_access_modifier
    access = AccessModifier.new
    if lookahead?(PublicToken)
      access.visibility = expect(PublicToken)
    elsif lookahead?(PrivateToken)
      access.visibility = expect(PrivateToken)
    end
    speculate(StaticToken) do
      access.is_static = true
    end
    return access
  end

  def parse_member_field
    expect(VarToken)
    name = expect(IdentifierToken)
    type = nil
    if lookahead?(ColonToken)
      type = parse_type_spec
    end
    @handler.start_member_field(name, type)
    speculate(AssignToken) do
      eat_expression
    end
    expect(SemicolonToken)
    @handler.end_member_field
  end

  def eat_expression
    until lookahead?(SemicolonToken)
      @lex.get_next
    end
  end

  def parse_member_function
    expect(FunctionToken)
    name = expect(IdentifierToken)
    sig = parse_function_signature
    @handler.member_function(name, sig)
    eat_block
  end

  def parse_function_signature
    sig = FunctionSignature.new
    expect(LParenToken)
    sig.arguments = parse_formal_argument_list
    expect(RParenToken)
    if lookahead?(ColonToken)
      sig.return_type = parse_type_spec
    end
    return sig
  end

  def parse_type_spec
    expect(ColonToken)
    parse_type_name
  end

  def parse_formal_argument_list
    list = []
    if lookahead?(IdentifierToken)
      list << parse_formal_argument
      while lookahead?(CommaToken)
        expect(CommaToken)
        list << parse_formal_argument
      end
    end
    list
  end

  def eat_block
    expect(LBraceToken)
    until lookahead?(RBraceToken)
      if lookahead?(LBraceToken)
        eat_block
      else
        @lex.get_next
      end
    end
    expect(RBraceToken)
  end

  def parse_formal_argument
    name = expect(IdentifierToken)
    arg = Argument.new(name)
    if lookahead?(ColonToken)
      arg.type = parse_type_spec
    end
    arg
  end

 private
  def expect(kind)
    tok = @lex.get_next
    unless tok.is_a?(kind)
      err("Expected '#{kind}' but found '#{tok.inspect}'");
    end
    tok
  end

  def lookahead?(kind)
    @lex.peek_next.is_a?(kind)
  end

  def speculate(kind)
    if lookahead?(kind)
      expect(kind)
      yield
    end
  end

  def err(msg)
    raise msg
  end
end

class ASHandler
  def compilation_unit_start; end
  def compilation_unit_end; end

  def import(name); end

  def comment(text); end
  def whitespace(text); end

  def start_class(dynamic, name, super_name, interfaces); end
  def end_class; end

  def access_modifier(modifier); end

  def member_function(name, sig); end

  def start_member_field(name, type); end
  def end_member_field; end
end

end # module Parse
end # module ActionScript
