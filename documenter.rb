
require 'parse/lexer'
require 'parse/parser'
require 'doc_comment'
require 'api_model'


# We used to just define the class again to add this attribute, but I want
# to be compatable with Ruby1.6, which doesn' allow 'class ModName::ClassName'
ActionScript::Parse::ASToken.module_eval("attr_accessor :last_comment")


class DocASParser < ActionScript::Parse::ASParser
  def parse_class_or_intrinsic_definition
    @handler.doc_comment @lex.peek_next.last_comment
    super()
  end

  def parse_interface_definition
    @handler.doc_comment @lex.peek_next.last_comment
    super()
  end

  def parse_class_member
    @handler.doc_comment @lex.peek_next.last_comment
    super()
  end

  def parse_interface_function
    @handler.doc_comment @lex.peek_next.last_comment
    super()
  end
end

class DocASLexer < ActionScript::Parse::SkipASLexer
  def initialize(io)
    super(io)
    @last_comment= nil
  end

  attr_accessor :last_comment
  protected
  def skip?(tok)
    if tok.instance_of?(ActionScript::Parse::MultiLineCommentToken) &&
       tok.body =~ /^\*/
      @last_comment = tok
    end
    result = super(tok)
    unless result
      if @last_comment
        tok.last_comment = @last_comment
	@last_comment = nil
      end
    end
    result
  end
end



# Resolves type-names in a particular compilation unit
class ImportManager
  def initialize
    @types = []
    @packages = []
  end

  def add_import(name)
    if name.last.instance_of?(ActionScript::Parse::StarToken)
      name.pop
      add_package_import(name)
    else
      add_type_import(name)
    end
  end

  def add_type_import(name)
    @types << name
  end

  def each_type
    @types.each do |type_name|
      yield type_name
    end
  end

  def add_package_import(name)
    @packages << name
  end

  def each_package
    @packages.each do |package_name|
      yield package_name
    end
  end
end

class TypeProxy
  def initialize(name)
    @name = name
    @resolved_type = nil
  end

  attr_accessor :name, :resolved_type

  def resolved?
    !@resolved_type.nil?
  end

  def local_name
    # TODO: come up with smarter representations for resolved vs. unresolved
    #       types
    @name.join(".")
  end

  def qualified?
    @name.size > 1
  end
end

class LocalTypeResolver
  def initialize
    @named_types = {}
  end

  def resolve(name)
    type = @named_types[name.join(".")]
    if type.nil?
      type = TypeProxy.new(name)
      @named_types[name.join(".")] = type
    end
    type
  end

  def each
    @named_types.each_value do |type|
      yield type
    end
  end
end


class GlobalTypeAgregator
  def initialize
    @types = []
    @packages = {}
  end

  def add_type(type)
    @types << type
    package_name = type.package_name
    package = @packages[package_name]
    if package.nil?
      package = ASPackage.new(package_name)
      @packages[package_name] = package
    end
    package.add_type(type)
  end

  def each_type
    @types.each do |type|
      yield type
    end
  end

  def each_package
    @packages.each_value do |package|
      yield package
    end
  end

  def packages
    @packages.values
  end

  # Eeek!...
  def resolve_types
    qname_map = {}
    @types.each do |type|
      qname_map[type.qualified_name] = type
    end
    @types.each do |type|
      local_namespace = qname_map.dup
      import_types_into_namespace(type, local_namespace)
      import_packages_into_namespace(type, local_namespace)
      resolver = type.type_resolver
      resolver.each do |type_proxy|
	real_type = local_namespace[type_proxy.name.join(".")]
	if real_type
	  type_proxy.resolved_type = real_type
	else
	  $stderr.puts "#{type.input_filename}:#{type_proxy.name.first.lineno}: Found no defenition of type known locally as #{type_proxy.name.join('.').inspect}"
	end
      end
    end
  end

  private

  def collect_package_types(package_name)
    @types.each do |type|
      if type.package_name == package_name
	yield type
      end
    end
  end

  def import_types_into_namespace(type, local_namespace)
    importer = type.import_manager
    importer.each_type do |type_name|
      import_type = local_namespace[type_name.join(".")]
      if import_type
	local_namespace[type_name.last.body] = import_type
      else
	$stderr.puts "#{type.input_filename}:#{type_name.first.lineno}: Couldn't resolve import of #{type_name.join(".").inspect}"
      end
    end
  end

  def import_packages_into_namespace(type, local_namespace)
    importer = type.import_manager
    importer.each_package do |package_name|
      collect_package_types(package_name.join(".")) do |package_type|
	if local_namespace.has_key?(package_type.unqualified_name)
	  $stderr.puts "#{package_type.unqualified_name} already refers to #{local_namespace[package_type.unqualified_name].qualified_name}"
	end
	local_namespace[package_type.unqualified_name] = package_type
      end
    end
  end
end

class DocASHandler < ActionScript::Parse::ASHandler
  def compilation_unit_start
    @type_resolver = LocalTypeResolver.new
    @import_manager = ImportManager.new
    @defined_type = nil
  end

  attr_accessor :defined_type

  def doc_comment(comment)
    @doc_comment = comment
  end

  def import(name)
    @import_manager.add_import(name)
  end

  def start_class(dynamic, name, super_name, interfaces)
    @defined_type = ASClass.new(name)
    if @doc_comment
      @defined_type.comment = @doc_comment
    end
    @defined_type.dynamic = dynamic
    if super_name
      @defined_type.extends = @type_resolver.resolve(super_name)
    end
    if interfaces
      interfaces.each do |interface|
        @defined_type.add_interface(@type_resolver.resolve(interface))
      end
    end
    @defined_type.type_resolver = @type_resolver
    @defined_type.import_manager = @import_manager
  end

  def start_intrinsic_class(dynamic, name, super_name, interfaces)
    start_class(dynamic, name, super_name, interfaces)
    @defined_type.intrinsic = true
  end

  def start_interface(name, super_name)
    @defined_type = ASInterface.new(name)
    if @doc_comment
      @defined_type.comment = @doc_comment
    end
    if super_name
      @defined_type.extends = @type_resolver.resolve(super_name)
    end
    @defined_type.type_resolver = @type_resolver
    @defined_type.import_manager = @import_manager
  end


  def access_modifier(modifier)
    @last_modifier = modifier
  end

  def show_modifier
    visibility  = @last_modifier.visibility
    if visibility.instance_of?(ActionScript::Parse::PublicToken)
      print "public "
    elsif visibility.instance_of?(ActionScript::Parse::PrivateToken)
      print "private "
    end
    if @last_modifier.is_static
      print "static "
    end
  end

  def start_member_field(name, type)
    field = ASField.new(@last_modifier, name.body)
    unless type.nil?
      field.field_type = @type_resolver.resolve(type)
    end
    @defined_type.add_field(field)
  end

  def interface_function(name, sig)
    member_function(name, sig)
  end

  def intrinsic_member_function(name, sig)
    member_function(name, sig)
  end

  def member_function(name, sig)
    method = ASMethod.new(@last_modifier, name.body)
    if sig.return_type
      method.return_type = @type_resolver.resolve(sig.return_type)
    end
    sig.arguments.each do |arg|
      argument = ASArg.new(arg.name.body)
      if arg.type
        argument.arg_type = @type_resolver.resolve(arg.type)
      end
      method.add_arg(argument)
    end
    if @doc_comment
      method.comment = @doc_comment
    end
    @defined_type.add_method(method)
  end
end

def simple_parse(input)
  lex = DocASLexer.new(ActionScript::Parse::ASLexer.new(input))
  parse = DocASParser.new(lex)
  handler = DocASHandler.new
  parse.handler = handler
  parse.parse_compilation_unit
  handler.defined_type
end


BOM = "\357\273\277"

# Look for a byte-order-marker in the first 3 bytes of io.
# Eats the BOM and returns true on finding one; rewinds the stream to its
# start and returns false if none is found.
def detect_bom?(io)
  return true if io.read(3) == BOM
  io.seek(0)
  false
end


def parse_options
  
end

# lists the .as files in 'path', and it's subdirectories
def each_source(path)
  require 'find'
  path = path.sub(/\/+$/, "")
  Find.find(path) do |f|
    base = File.basename(f)
    # Ignore anything named 'CVS', or starting with a dot
    Find.prune if base =~ /^\./ || base == "CVS"
    if base =~ /\.as$/
      yield f[path.length+1, f.length]
    end
  end
end

# Support for other kinds of output would be useful in the future.
# When the need arises, maybe the interface to 'output' subsystems will need
# more formailisation than just 'document_types()'
require 'html_output'

type_agregator = GlobalTypeAgregator.new

path = ARGV[0]

each_source(path) do |name|
  File.open(File.join(path, name)) do |io|
    begin
      is_utf8 = detect_bom?(io)
      print "Parsing #{path}:#{name.inspect}"
      type = simple_parse(io)
      type.input_filename = name
      type.sourcepath_location(File.dirname(name))
      puts " -> #{type.qualified_name}"
      type.source_utf8 = is_utf8
      type_agregator.add_type(type)
    rescue =>e
      $stderr.puts "#{name}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end

type_agregator.resolve_types

document_types(type_agregator)
