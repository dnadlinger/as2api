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


require 'parse/aslexer'
require 'parse/parser'
require 'api_model'
require 'doc_comment'
require 'parse/doccomment_lexer'
require 'stringio'

# We used to just define the class again to add this attribute, but I want
# to be compatable with Ruby1.6, which doesn' allow 'class ModName::ClassName'
ActionScript::Parse::ASToken.module_eval("attr_accessor :last_comment")


def simple_parse(input, source)
  lex = ActionScript::Parse::ASLexer.new(input)
  lex.source = source
  skip = DocASLexer.new(lex)
  parse = DocASParser.new(skip)
  handler = DocASHandler.new(source)
  parse.handler = handler
  parse.parse_compilation_unit
  handler.defined_type
end


def parse_file(file)
  File.open(File.join(file.prefix, file.suffix)) do |io|
    begin
      is_utf8 = detect_bom?(io)
      astype = simple_parse(io, file.suffix)
      astype.input_file = file
      astype.source_utf8 = is_utf8
      return astype
    rescue =>e
      $stderr.puts "#{file.suffix}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end


# Hacked subclass of SkipASLexer that remembers multiline comment tokens as
# they're bing skipped over, and then pokes them into the next real token
# that comes by
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


# Take the comment tokens stuffed into 'real' tokens by DocASLexer, and
# pass these to our DocASHandler instance for parts of the grammar where
# they might contain API docs
class DocASParser < ActionScript::Parse::ASParser
  def parse_class_or_intrinsic_definition
    snarf_comment
    super()
  end

  def parse_interface_definition
    snarf_comment
    super()
  end

  def parse_class_member
    snarf_comment
    super()
  end

  def parse_interface_function
    snarf_comment
    super()
  end

  private

  def snarf_comment
    @handler.doc_comment @lex.peek_next.last_comment
  end
end


# Builds a model of the API being processed as ActionScript::Parse::Parser
# recognises pieces of the ActionScript grammar
class DocASHandler < ActionScript::Parse::ASHandler
  def initialize(source)
    @source = source
    parse_conf_build = ConfigBuilder.new
    @method_comment_config = parse_conf_build.build_method_config
    @field_comment_config = parse_conf_build.build_field_config
    @type_comment_config = parse_conf_build.build_type_config
  end

  def compilation_unit_start
    @import_list = ImportList.new
    @defined_type = nil
  end

  attr_accessor :defined_type

  def doc_comment(comment)
    @doc_comment = comment
  end

  def import(name)
    @import_list.add_import(name)
  end

  def start_class(dynamic, name, super_name, interfaces)
    pkg_name = name[0, name.length-1].join(".")
    cls_name = name.last.body
    @defined_type = ASClass.new(pkg_name, cls_name)
    @type_namespace = TypeLocalNamespace.new(@defined_type)
    if @doc_comment
      @defined_type.comment = parse_comment(@type_comment_config, @doc_comment)
    end
    @defined_type.dynamic = dynamic
    if super_name
      @defined_type.extends = @type_namespace.ref_to(super_name)
    end
    if interfaces
      interfaces.each do |interface|
        @defined_type.add_interface(@type_namespace.ref_to(interface))
      end
    end
    @defined_type.type_namespace = @type_namespace
    @defined_type.import_list = @import_list
  end

  def start_intrinsic_class(dynamic, name, super_name, interfaces)
    start_class(dynamic, name, super_name, interfaces)
    @defined_type.intrinsic = true
  end

  def start_interface(name, super_name)
    pkg_name = name[0, name.length-1].join(".")
    int_name = name.last.body
    @defined_type = ASInterface.new(pkg_name, int_name)
    @type_namespace = TypeLocalNamespace.new(@defined_type)
    if @doc_comment
      @defined_type.comment = parse_comment(@type_comment_config, @doc_comment)
    end
    if super_name
      @defined_type.extends = @type_namespace.ref_to(super_name)
    end
    @defined_type.type_namespace = @type_namespace
    @defined_type.import_list = @import_list
  end

  def access_modifier(modifier)
    vis = case modifier.visibility
      when ActionScript::Parse::PublicToken
	:public
      when ActionScript::Parse::PrivateToken
	:private
      when nil
	nil
      else
	raise "unhandled visibility #{modifier.visibility.inspect}"
    end
    @last_modifier = ASAccess.new(vis, modifier.is_static)
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

  def start_member_field(name, astype)
    field = ASExplicitField.new(@defined_type, @last_modifier, name.body)
    unless astype.nil?
      field.field_type = @type_namespace.ref_to(astype)
    end
    if @doc_comment
      field.comment = parse_comment(@field_comment_config, @doc_comment)
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
    if sig.implicit_property_modifier.nil?
      real_member_function(name, sig)
    else
      implicit_property_function(name, sig)
    end
  end

  private

  def create_method(name, sig)
    method = ASMethod.new(@defined_type, @last_modifier, name.body)
    if sig.return_type
      method.return_type = @type_namespace.ref_to(sig.return_type)
    end
    sig.arguments.each do |arg|
      argument = ASArg.new(arg.name.body)
      if arg.type
        argument.arg_type = @type_namespace.ref_to(arg.type)
      end
      method.add_arg(argument)
    end
    if @doc_comment
      method.comment = parse_comment(@method_comment_config, @doc_comment)
    end
    method
  end

  def real_member_function(name, sig)
    method = create_method(name, sig)
    if name.body == @defined_type.unqualified_name
      @defined_type.constructor = method
    else
      @defined_type.add_method(method)
    end
  end

  def implicit_property_function(name, sig)
    field = @defined_type.get_field_called(name.body)
    if field.nil?
      field = ASImplicitField.new(@defined_type, name.body)
      @defined_type.add_field(field)
    end
    func = create_method(name, sig)
    if sig.implicit_property_modifier == "get"
      field.getter_method = func
    elsif sig.implicit_property_modifier == "set"
      field.setter_method = func
    else
      raise "unknown property-modifier #{sig.implicit_property_modifier.inspect}"
    end
  end

  def parse_comment(config, comment_token)
    comment_data = CommentData.new

    input = StringIO.new(comment_token.body)
    input.lineno = comment_token.lineno - 1
    lexer = ActionScript::ParseDoc::DocCommentLexer.new(input)
    lexer.source = @source
    parser = ActionScript::ParseDoc::DocCommentParser.new(lexer)
    handler = OurDocCommentHandler.new(comment_data, config, @type_namespace)
    parser.handler = handler

    parser.parse_comment

    comment_data
  end
end


# The following classes could maybe be split into a different unit from those
# above


# Records the classes and packages imported into a compilation unit
class ImportList
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


# A proxy for some type referred to by a particular name within a compilation
# unit.  After we've parsed all compilation units, we'll be able to resolve
# what real type this reference stands for (i.e. becase we'll have found the
# types pulled into the compilation unit by 'import com.example.*')
class TypeRef
  # TODO: this should be in api_model.rb

  def initialize(containing_type, name)
    @name = name
    @containing_type = containing_type
    @resolved_type = nil
    @lineno = nil
  end

  attr_accessor :name, :containing_type, :resolved_type, :lineno

  def resolved?
    !@resolved_type.nil?
  end

  def local_name
    # TODO: come up with smarter representations for resolved vs. unresolved
    #       types
    @name
  end

  def qualified?
    @name =~ /\./
  end

  def ref_method(method_name, lineno)
    MethodRef.new(self, method_name, lineno)
  end

  def ref_member(member_name, lineno)
    MemberRef.new(self, member_name, lineno)
  end

  def ==(o)
    # note that types are considered to be equal here if they have the same
    # name; we don't recursively compare their whole subgraphs
    !o.nil? && name==o.name &&
    (containing_type.nil? == o.containing_type.nil?) &&
    (containing_type.nil? || containing_type.qualified_name == o.containing_type.qualified_name) &&
    (resolved_type.nil? == o.resolved_type.nil?) &&
    (resolved_type.nil? || resolved_type.qualified_name == o.resolved_type.qualified_name) &&
    lineno==o.lineno
  end

  def inspect
    "<#{self.class.name}:0x#{(object_id&0xffffffff).to_s(16)} @name=#{name.inspect} @containing_type=#{@containing_type ? @containing_type.qualified_name : "nil"} @resolved_type=#{@resolved_type ? @resolved_type.qualified_name : "nil"} @lineno=#{@lineno.inspect}>"
  end
end


# A reference, by name, to a member of a type, which may or may not actually
# exist.
class MemberRef
  def initialize(type_ref, member_name, lineno)
    @type_ref = type_ref
    @member_name = member_name
    @lineno = lineno
  end

  attr_reader :member_name

  def type_local_name
    @type_ref.local_name
  end

  def type_resolved?
    @type_ref.resolved?
  end
  def resolved_type
    @type_ref.resolved_type
  end

  def resolved?
    # TODO: should report failures to resolve member refs during type
    #       resolution
    type_resolved? && !resolved_member.nil?
  end
  def resolved_member
    astype = @type_ref.resolved_type
    if astype.respond_to?(:get_field_called)
      field = astype.get_field_called(@member_name)
      return field if field
    end
    return astype.get_method_called(@member_name)
  end

  def ==(o)
    !o.nil? && member_name == o.member_name && type_local_name == o.type_local_name
  end
end

class MethodRef < MemberRef
  def resolved_method
    @type_ref.resolved_type.get_method_called(@member_name)
  end

  def resolved_member; resolved_method; end
end


# Resolves type names to instances of TypeRef for a particular compilation
# unit (the same name could refer to different types in different compilation
# units).
class TypeLocalNamespace
  def initialize(containing_type)
    @containing_type = containing_type
    @named_types = {}
    @ref_to_self = TypeRef.new(containing_type, containing_type.qualified_name)
  end

  def ref_to(name, lineno=nil)
    raise "invalid name #{name.inspect}" if name.nil?
    if name.is_a?(Array)
      lineno = name.first.lineno
      name = name.join(".")
    end
    type_ref = @named_types[name]
    if type_ref.nil?
      type_ref = TypeRef.new(@containing_type, name)
      type_ref.lineno = lineno
      @named_types[name] = type_ref
    end
    type_ref
  end

  attr_reader :ref_to_self

  def each
    @named_types.each_value do |astype|
      yield astype
    end
  end
end


# Collects types that are produced by parsing compilation units, building the
# package list as types from different packages are added.
class GlobalTypeAggregator
  def initialize()
    @types = []
    @packages = {}
  end

  def add_type(astype)
    @types << astype
    package_name = astype.package_name
    package = @packages[package_name]
    if package.nil?
      package = ASPackage.new(package_name)
      @packages[package_name] = package
    end
    astype.package = package
    package.add_type(astype)
  end

  def each_type
    @types.each do |astype|
      yield astype
    end
  end

  def types
    @types.dup
  end

  def each_package
    @packages.each_value do |package|
      yield package
    end
  end

  def packages
    @packages.values
  end

  def package(name)
    @packages[name]
  end
end


# Utility for resolving the TypeRef objects created within each ASType of
# a GlobalTypeAggregator.
#
# Once all types to be documented have been parsed, this class resolves the
# inter-type references that the TypeRef objects represent, possibly loading
# and parsing further ActionScript files from the classpath as type-resolution
# requires.
class TypeResolver
  def initialize(classpath)
    @classpath = classpath
    @parsed_external_types = {}
  end

  def resolve_types(type_aggregator)
    global_ns = create_default_global_namespace
    add_fully_qualified_types_to_namespace(global_ns, type_aggregator)
    resolve_each_type(global_ns, type_aggregator)
  end

  private

  def err(filename, lineno, msg)
    $stderr.puts "#{filename}:#{lineno}: #{msg}"
  end

  def create_default_global_namespace
    ns = {}
    ns[AS_VOID.qualified_name] = AS_VOID
    ns
  end

  def add_fully_qualified_types_to_namespace(ns, type_aggregator)
    type_aggregator.each_type do |astype|
      ns[astype.qualified_name] = astype
    end
  end

  def create_local_namespace(global_ns, type_aggregator, astype)
    ns = global_ns.dup
    ns[astype.unqualified_name] = astype
    import_types_into_namespace(astype, ns)
    import_packages_into_namespace(type_aggregator, astype, ns)
    ns
  end

  def resolve_each_type(global_ns, type_aggregator)
    type_aggregator.each_type do |astype|
      local_ns = create_local_namespace(global_ns, type_aggregator, astype)
      resolve_type_refs(local_ns, astype)
    end
  end

  def resolve_type_refs(local_ns, astype)
    astype.type_namespace.each do |type_ref|
      real_type = local_ns[type_ref.local_name]
      unless real_type
	real_type = maybe_parse_external_definition(type_ref)
      end
      if real_type
	type_ref.resolved_type = real_type
      else
	err(astype.input_filename, type_ref.lineno, "Found no definition of type known locally as #{type_ref.local_name.inspect}")
      end
    end
  end

  def import_types_into_namespace(astype, local_namespace)
    astype.import_list.each_type do |type_name|
      import_type = local_namespace[type_name.join(".")]
      import_type = maybe_parse_external_definition(TypeRef.new(astype, type_name.join('.'))) unless import_type
      if import_type
	local_namespace[type_name.last.body] = import_type
      else
	err(astype.input_filename, type_name.first.lineno, "Couldn't resolve import of #{type_name.join(".").inspect}")
      end
    end
  end

  def import_packages_into_namespace(type_aggregator, astype, local_namespace)
    astype.import_list.each_package do |package_name|
      pkg = type_aggregator.package(package_name.join("."))
      unless pkg
	err(astype.input_filename, package_name.first.lineno, "Couldn't find package #{package_name.join(".").inspect}")
	next
      end
      pkg.each_type do|package_type|
	next if astype.qualified_name == package_type.qualified_name
	if local_namespace.has_key?(package_type.unqualified_name)
	  err(astype.input_filename, package_name.first.lineno, "#{package_type.unqualified_name} already refers to #{local_namespace[package_type.unqualified_name].qualified_name}")
	end
	local_namespace[package_type.unqualified_name] = package_type
      end
    end
  end

  def classname_to_filename(qualified_class_name)
    return qualified_class_name.gsub(/\./, File::SEPARATOR) + ".as"
  end

  def search_classpath_for(qualified_class_name)
    filename = classname_to_filename(qualified_class_name)

    @classpath.each do |path|
      if FileTest.exist?(File.join(path, filename))
	return SourceFile.new(path, filename)
      end
    end

    nil
  end

  def find_file_matching(type_ref)
    file_name = search_classpath_for(type_ref.name)
    return file_name unless file_name.nil?
    return nil if type_ref.qualified?

    type_ref.containing_type.import_list.each_package do |package_name|
      candidate_name = package_name.join(".") + "." + type_ref.name
      file_name = search_classpath_for(candidate_name)
      return file_name unless file_name.nil?
    end

    nil
  end

  def maybe_parse_external_definition(type_ref)
    source_file = find_file_matching(type_ref)
    return nil if source_file.nil?
    astype = @parsed_external_types[source_file.suffix]
    return astype unless astype.nil?
    astype = parse_file(source_file)
    astype.document = false
    @parsed_external_types[source_file.suffix] = astype

    astype
  end
end

# vim:softtabstop=2:shiftwidth=2
