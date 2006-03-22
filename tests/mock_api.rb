
require 'api_loader'
require 'stringio'


module MockAPI

  # TODO: use proper ver once factored out from ui/cli.rb,
  SourceFile = Struct.new(:prefix, :suffix)

  def self.create
    type_aggregator = GlobalTypeAggregator.new
    type_aggregator.add_type(create_TestClass)
    type_aggregator.add_type(create_TestInterface)
    type_aggregator.add_type(create_AInterface)
    type_aggregator.add_type(create_AClass)
    type_aggregator.add_type(create_BClass)
    type_resolver = TypeResolver.new([])
    type_resolver.resolve_types(type_aggregator)
    type_aggregator
  end

  def self.create_TestClass
    parse_file "TestClass.as", <<-END
      /**
       * Test class
       */
      class TestClass implements TestInterface {
	/**
	 * A text field {@link #doSoemthing()}
	 */
	public var text:AClass;

	private var number:pkg.BClass;

	/**
	 * Test constructor.
	 */
	public function TextClass() {
	}

	/**
	 * Does some stuff
	 * 
	 * @param anArg some argument value
	 * @return some resulting string
	 *
	 * @throws TestInterface when the workld ends
	 */
	public function doSomething(anArg:AClass):pkg.BClass {
	}
      }
    END
  end

  def self.create_AClass
    parse_file "AClass.as", <<-END
      /**
       * A class
       * 
       * @see TestInterface
       */
      class AClass {
	public function noDocs(foo):pkg.BClass { }
      }
    END
  end

  def self.create_BClass
    parse_file "pkg/BClass.as", <<-END
      /**
       * B class
       */
      class pkg.BClass extends AClass {
      }
    END
  end

  def self.create_TestInterface
    parse_file "TestInterface.as", <<-END
      /**
       * Test interface {@link pkg.BClass text for link}.
       */
      interface TestInterface {
      }
    END
  end

  def self.create_AInterface
    parse_file "AInterface.as", <<-END
      /**
       * A interface
       *
       * @see AClass some link text
       */
      interface AInterface extends TestInterface {
      }
    END
  end

  def self.parse_file(mock_filename, sourcecode)
    io = StringIO.new(sourcecode)
    lex = ActionScript::Parse::ASLexer.new(io)
    lex.source = mock_filename
    skip = DocASLexer.new(lex)
    parse = DocASParser.new(skip)
    handler = DocASHandler.new(mock_filename)
    parse.handler = handler
    parse.parse_compilation_unit
    handler.defined_type.input_file = SourceFile.new("", mock_filename)
    handler.defined_type
  end
end

# vim:sw=2:sts=2
