
require 'parse/lexer'
require 'parse/parser'
require 'xmlwriter'
require 'doc_comment'

class ASType
  def initialize(name)
    @name = name
    @resolved = false
    @is_class = nil
    @methods = []
    @dynamic = false
    @extends = nil
    @comment = nil
    @interfaces = []
  end

  attr_accessor :package, :name, :resolved, :dynamic, :extends, :comment

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
  def initialize(access, name, signature)
    @access = access
    @name = name
    @signature = signature
  end

  attr_accessor :access, :name, :signature, :comment
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

  def add_package_import(name)
    @packages << name
  end
end

class UnresolvedType
  def initialize(name)
    @name = name
  end

  attr_accessor :name
end

class TypeResolver
  def initialize
    @named_types = {}
  end

  def resolve(name)
    type = @named_types[name]
    if type.nil?
      type = UnresolvedType.new(name)
      @named_types[name] = type
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
    @type_resolver = TypeResolver.new
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
    method = ASMethod.new(@last_modifier, name.body, sig)
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

def method_synopsis(out, method)
  out.element("code", {"class", "method_synopsis"}) do
    if method.access.is_static
      out.pcdata("static ")
    end
    unless method.access.visibility.nil?
      out.pcdata("#{method.access.visibility.body} ")
    end
    out.pcdata("function ")
    out.element("strong", {"class"=>"method_name"}) do
      out.pcdata(method.name)
    end
    out.pcdata("(")
    method.signature.arguments.each_with_index do |arg, index|
      out.pcdata(", ") if index > 0
      out.pcdata(arg.name.body)
      if arg.type
        out.pcdata(":#{arg.type.join('.')}")
      end
    end
    out.pcdata(")")
    if method.signature.return_type
      out.pcdata(":#{method.signature.return_type.join('.')}")
    end
  end
end

def class_navigation(out)
  out.element("div", {"class", "main_nav"}) do
    out.simple_element("a", "Overview", {"href"=>"index.html"})
    out.simple_element("span", "Package")
    out.simple_element("span", "Class", {"class"=>"nav_current"})
  end
end

def document_method(out, method)
  out.empty_tag("a", {"name"=>"method_#{method.name}"})
  out.simple_element("h3", method.name)
  out.element("div", {"class"=>"method_details"}) do
    method_synopsis(out, method)
    if method.comment
      out.element("blockquote") do
	docs = DocComment.new
	docs.parse(method.comment.body)
        out.pcdata(docs.description)
        out.element("dl", {"class"=>"method_detail_list"}) do
	  # TODO: assumes that params named in docs match formal arguments
	  #       should really filter out those that don't match before this
	  #       test
	  if docs.parameters?
	    out.simple_element("dt", "Parameters")
	    out.element("dd") do
	      out.element("table", {"class"=>"arguments"}) do
		method.signature.arguments.each do |arg|
		  desc = docs.param(arg.name.body)
		  if desc
		    out.element("tr") do
		      out.element("td") do
			out.simple_element("code", arg.name.body)
		      end
		      out.simple_element("td", desc)
		    end
		  end
		end
	      end
	    end
	  end
	  if docs.exceptions?
            out.simple_element("dt", "throws")
            out.element("dd") do
	      out.element("table", {"class"=>"exceptions"}) do
	        docs.each_exception do |type, desc|
		  out.element("tr") do
		    out.element("td") do
		      out.simple_element("code", type)
		    end
		    out.simple_element("td", desc)
		  end
	        end
	      end
	    end
	  end
	end
      end
    end
  end
end

def document_type(type)
  File.open("apidoc/" + type.name.join(".") + ".html", "w") do |io|
    out = XMLWriter.new(io)
    out.element("html") do
      out.element("head") do
        out.simple_element("title", type.name.join("."))
        out.empty_tag("link", {"rel"=>"stylesheet", "type"=>"text/css", "href"=>"style.css"})
      end

      out.element("body") do
        class_navigation(out)
        out.simple_element("h1", type.name.join("."))
	if type.implements_interfaces?
          out.element("div", {"class"=>"interfaces"}) do
            out.simple_element("h2", "Implemented Interfaces")
	    type.each_interface do |interface|
	      # TODO: need to resolve interface name, make links
              out.simple_element("code", interface.join('.'))
	      out.pcdata(" ")
	    end
	    out.comment(" no more interfaces ")
          end
        end
        out.element("div", {"class"=>"type_description"}) do
	  if type.comment
            out.simple_element("h2", "Description")
            out.element("p") do
	      out.pcdata(type.comment.body)
	    end
	  end
	end
        out.element("div", {"class"=>"method_index"}) do
          out.simple_element("h2", "Method Index")
	  type.each_method do |method|
            out.element("a", {"href"=>"#method_#{method.name}"}) do
	      out.pcdata(method.name+"()")
	    end
	    out.pcdata(" ")
	  end
	end

        out.element("div", {"class"=>"method_detail_list"}) do
          out.simple_element("h2", "Method Detail")
	  type.each_method do |method|
	    document_method(out, method)
	  end
	end
        class_navigation(out)
      end
    end
  end
end

File.open("apidoc/index.html", "w") do |out|
  ARGV.each do |name|
    File.open(name) do |io|
      begin
        type = simple_parse(io)
        document_type(type)
	out.puts("<p><a href=\"#{type.name.join('.')}.html\">#{type.name.join('.')}</a></p>")
      rescue =>e
        $stderr.puts "#{name}: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
