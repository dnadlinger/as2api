
# These classes represent the data-model upon which as2api operates.  The
# class names are all prefixed with 'AS' becase many would otherwise clash
# with Ruby's inbuild classes with the same name.


# TODO: The interfaces to these classes still, in places, make direct use of
#       types provided by ActionScript::Parse (i.e. methods expecting or
#       returning subclasses of ASToken).  These classes should be refactored
#       to insulate the documentation-generating subsystem from those details


# Superclass for ASClass and ASInterface, one instance of an ASType subclass
# is created per compilation unit successfully parsed
class ASType
  # give this ASType the given name (an array of IdentifierToken values
  # found by the parser)
  def initialize(name)
    @package_name = name[0, name.length-1].join(".")
    @name = name.last.body
    @source_utf8 = false
    @methods = []
    @extends = nil
    @comment = nil
    @type_resolver = nil
    @import_manager = nil
    @input_filename = nil
  end

  attr_accessor :package, :extends, :comment, :source_utf8, :type_resolver, :import_manager, :input_filename, :intrinsic

  def add_method(method)
    @methods << method
  end

  def each_method
    @methods.each do |meth|
      yield meth
    end
  end

  def methods?
    !@methods.empty?
  end

  # The type's name, excluding its package-prefix
  def unqualified_name
    @name
  end

  # The whole type name, including package-prefix
  def qualified_name
    if @package_name == ""
      @name
    else
      "#{@package_name}.#{@name}"
    end
  end

  # The package-prefix on this type's name
  def package_name
    @package_name
  end

  # This exists mostly as a hack to handle types that are declaired without
  # a package-prefix 'class SomeClass {', but shich are located in the
  # directory structure such that a package is implied (and indeed used by
  # Flash when the fileis found).
  # 
  # When a type has no package-prefix, and this method is called on it with
  # an argument "com/foobar", we will 're-package' the type to subsequently
  # become 'com.foobar.SomeClass'
  def sourcepath_location(path)
    path = "" if path == "."
    if @package_name == "" and path != ""
      @package_name = path.gsub("/", ".")
    else
      if @package_name != path.gsub("/", ".")
	$stderr.puts("package #{@package_name.inspect} doesn't match location #{path.inspect}")
      end
    end
  end

  def document?
    true
  end
end

class ASVoidType < ASType
  def initialize
    @name = "Void"
    @package_name = ""
  end

  def document?
    false
  end
end

AS_VOID = ASVoidType.new

# Classes are types that (just for the perposes of API docs) have fields, and
# implement interfaces
class ASClass < ASType
  def initialize(name)
    @dynamic = false
    @interfaces = []
    @fields = []
    super(name)
  end

  attr_accessor :dynamic

  def implements_interfaces?
    !@interfaces.empty?
  end

  def add_interface(name)
    @interfaces << name
  end

  def each_interface
    @interfaces.each do |name|
      yield name
    end
  end

  def add_field(field)
    @fields << field
  end

  def fields?
    !@fields.empty?
  end

  def each_field
    @fields.each do |field|
      yield field
    end
  end

  def get_field_called(name)
    each_field do |field|
      return field if field.name == name
    end
    nil
  end
end

# ASInterface doesn't add anything to the superclass, it just affirms that
# the API only supported by ASClass will not be available here
class ASInterface < ASType
  def initialize(name)
    super(name)
  end

  def implements_interfaces?
    false
  end

  def fields?
    false
  end
end

# A member in some type
class ASMember
  def initialize(access, name)
    @access = access
    @name = name
    @comment = nil
  end

  attr_accessor :access, :name, :comment
end

# A method member, which may appear in an ASClass or ASInterface
class ASMethod < ASMember
  def initialize(access, name)
    super(access, name)
    @return_type = nil
    @args = []
  end

  attr_accessor :return_type

  def add_arg(arg)
    @args << arg
  end

  def arguments
    @args
  end

  def agument(index)
    @args[index]
  end
end

# A field member, which may appear in an ASClass, but not an ASInterface
class ASField < ASMember
end

class ASExplicitField < ASField
  def initialize(access, name)
    super(access, name)
    @field_type = nil
  end

  attr_accessor :field_type

  def readwrite?; true; end

  def read?; true; end

  def write?; true; end
end

# A field implied by the presence of "get" or "set" methods with this name
class ASImplicitField < ASField
  def initialize(name)
    super(nil, name)
    @getter_method = nil
    @setter_method = nil
  end

  attr_accessor :getter_method, :setter_method

  def readwrite?
    !(@getter_method.nil? || @setter_method.nil?)
  end

  def read?
    !@getter_method.nil?
  end

  def write?
    !@setter_method.nil?
  end

  def access
    (@getter_method || @setter_method).access
  end

  def comment
    (@getter_method || @setter_method).comment
  end

  def field_type
    if read?
      return @getter_method.return_type
    else
      unless @setter_method.arguments.empty?
	arg = @setter_method.arguments[0]
	return arg.arg_type
      end
    end
    return nil
  end
end

# A formal function parameter, a list of which appear in an ASMethod
class ASArg
  def initialize(name)
    @name = name
    @arg_type = nil
  end

  attr_accessor :name, :arg_type
end

# A simple aggregation of ASType objects
class ASPackage
  def initialize(name)
    @name = name
    @types = []
  end

  attr_accessor :name
  
  def add_type(type)
    @types << type
  end

  def each_type
    @types.each do |type|
      yield type
    end
  end
end
