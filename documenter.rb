
require 'parse/lexer'
require 'parse/parser'
require 'doc_comment'

class ASType
  def initialize(name)
    @name = name
    @source_utf8 = false
    @resolved = false
    @is_class = nil
    @methods = []
    @dynamic = false
    @extends = nil
    @comment = nil
    @interfaces = []
    @type_resolver = nil
    @import_manager = nil
  end

  attr_accessor :package, :name, :resolved, :dynamic, :extends, :comment, :source_utf8, :type_resolver, :import_manager

  def class?
    @is_class
  end

  def interface?
    !@is_class
  end

  def add_method(method)
    @methods << method
  end

  def each_method
    @methods.each do |meth|
      yield meth
    end
  end

  def add_interface(name)
    @interfaces << name
  end

  def each_interface
    @interfaces.each do |name|
      yield name
    end
  end

  def unqualified_name
    @name.last.body
  end

  def name_s
    @name.join(".")
  end

  def package_name
    @name[0, @name.length-1]
  end

  def package_name_s
    package_name.join(".")
  end

  def implements_interfaces?
    !@interfaces.empty?
  end
end

class ActionScript::Parse::ASToken
  attr_accessor :last_comment
end

class DocASParser < ActionScript::Parse::ASParser
  def parse_class_definition
    @handler.doc_comment @lex.peek_next.last_comment
    super()
  end

  def parse_class_member
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

class ASMethod
  def initialize(access, name)
    @access = access
    @name = name
    @return_type = nil
    @args = []
  end

  attr_accessor :access, :name, :comment, :return_type

  def add_arg(arg)
    @args << arg
  end

  def arguments
    @args
  end
end

class ASArg
  def initialize(name)
    @name = name
    @arg_type = nil
  end

  attr_accessor :name, :arg_type
end

class ASPackage
  def initialize(name)
    @name = name
  end

  def to_s
    result = ''
    name.each_with_index do |part, index|
      result << "." if index > 0
      result << part
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
    @defined_type = ASType.new(name)
    if @doc_comment
      @defined_type.comment = @doc_comment
    end
    @defined_type.dynamic = dynamic
    if super_name
      @defined_type.extends = super_name
    end
    if interfaces
      interfaces.each do |interface|
        @defined_type.add_interface(interface)
      end
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
    show_modifier
    print "var "
    print name.body
    unless type.nil?
      print ":"
      print type
    end
    puts ";"
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

# returns an array of the .as files in 'path', and it's subdirectories
def each_source(path)
  require 'find'
  Find.find(path) do |f|
    base = File.basename(f)
    Find.prune if base =~ /^\./ || base == "CVS"
    if base =~ /\.as$/
      yield f #[path.length, f.length]
    end
  end
end

def collect_package_types(types, package_name)
  types.each do |type|
    if type.package_name_s == package_name
      yield type
    end
  end
end

# Eeek!...
def resolve_types(types)
  qname_map = {}
  types.each do |type|
    qname_map[type.name_s] = type
  end
  types.each do |type|
    importer = type.import_manager
    local_names = qname_map.dup
    importer.each_type do |type_name|
      import_type = qname_map[type_name.join(".")]
      if import_type
        local_names[type_name.last.body] = import_type
      else
        $stderr.puts "Couldn't resolve import of #{type_name.inspect}"
      end
    end
    importer.each_package do |package_name|
      collect_package_types(types, package_name.join(".")) do |package_type|
	if local_names.has_key?(package_type.unqualified_name)
          $stderr.puts "#{package_type.unqualified_name} already refers to #{local_names[package_type.unqualified_name].name_s}"
	end
        local_names[package_type.unqualified_name] = package_type
      end
    end
    resolver = type.type_resolver
    resolver.each do |type_proxy|
      real_type = local_names[type_proxy.name.join(".")]
      if real_type
	type_proxy.resolved_type = real_type
      else
	$stderr.puts "No match for local type #{type_proxy.name.join('.').inspect}"
      end
    end
  end
end

# Support for other kinds of output would be useful, in the future.
# When the need arises, maybe the interface to 'output' subsystems will need
# more formailisation than just 'document_types()'
require 'html_output'

types = []

each_source(ARGV[0]) do |name|
  File.open(name) do |io|
    begin
      is_utf8 = detect_bom?(io)
      print "Parsing #{name.inspect}"
      type = simple_parse(io)
      puts " -> #{type.name_s}"
      type.source_utf8 = is_utf8
      types << type
    rescue =>e
      $stderr.puts "#{name}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end

resolve_types(types)

document_types(types)
