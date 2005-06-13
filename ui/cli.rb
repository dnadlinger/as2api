
require 'documenter'
require 'getoptlong'
require 'html_output'

Conf = Struct.new(:output_dir, :classpath, :package_filters)

SourceFile = Struct.new(:prefix, :suffix)

class PackageFilter
  def initialize(package_spec)
    @package_spec = Regexp.new("^" + package_spec.gsub(/\./, "/") + "/[^/]+$")
  end

  def matches?(source_file)
    @package_spec =~ source_file
  end
end

class PackageGlobFilter
  def initialize(package_spec)
    @package_spec = Regexp.new("^" + package_spec.gsub(/\./, "/"))
  end

  def matches?(source_file)
    @package_spec =~ source_file
  end
end


class CLI

  def parse_opts
    opts = GetoptLong.new(
      [ "--help",       "-h", GetoptLong::NO_ARGUMENT ],
      [ "--output-dir", "-d", GetoptLong::REQUIRED_ARGUMENT ],
      [ "--classpath",  "-c", GetoptLong::REQUIRED_ARGUMENT ]
    )

    conf = Conf.new
    conf.classpath = []
    conf.package_filters = []

    opts.each do |opt, arg|
      case opt
	when "--output-dir"
	  conf.output_dir = arg
	when "--classpath"
	  conf.classpath.concat(arg.split(File::PATH_SEPARATOR))
	when "--help"
	  usage
	  exit(0)
      end
    end
    if ARGV.empty?
      usage
      error("No packages specified")
    end
    ARGV.each do |package_spec|
      conf.package_filters << to_filter(package_spec)
    end

    conf.classpath << "." if conf.classpath.empty?
    conf.output_dir = "apidoc" if conf.output_dir.nil?

    conf
  end

  def to_filter(package_spec)
    case package_spec
      when /\.\*$/
	PackageGlobFilter.new($`)
      else
	PackageFilter.new(package_spec)
    end
  end

  def process_file?(name)
    @conf.package_filters.each do |filter|
      return true if filter.matches?(name)
    end
    false
  end

  def find_sources
    result = []
    @conf.classpath.each do |path|
      each_source(path) do |source|
	result << SourceFile.new(path, source) if process_file?(source)
      end
    end
    result
  end

  def parse_file(file, type_agregator)
    File.open(File.join(file.prefix, file.suffix)) do |io|
      begin
	is_utf8 = detect_bom?(io)
	print "Parsing #{file.prefix}:#{file.suffix}"
	type = simple_parse(io)
	type.input_filename = file.suffix
	type.sourcepath_location(File.dirname(file.suffix))
	puts " -> #{type.qualified_name}"
	type.source_utf8 = is_utf8
	type_agregator.add_type(type)
      rescue =>e
	$stderr.puts "#{file.suffix}: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  def parse_all(files)
    type_agregator = GlobalTypeAggregator.new
    files.each do |file|
      parse_file(file, type_agregator)
    end
    type_agregator
  end

  def main
    @conf = parse_opts
    files = find_sources
    error("No source files matching specified packages") if files.empty?
    type_agregator = parse_all(files)
    type_agregator.resolve_types
    document_types(@conf.output_dir, type_agregator)
  end

  def usage
    puts <<-END
Usage:
  #{$0} [options] <package spec> ...

A package spec can be given as:

  com.example.pkg
        Document types in the package 'com.example.pkg'.
  com.example.pkg.*
        Document types in the package 'com.example.pkg', and any other packages
        with the same prefix (e.g. 'com.example.pkg.utils.extra' types too).

Where options include:

  --classpath <path>
        A list of paths, delimited by '#{File::PATH_SEPARATOR}'.  Each path will
	be searched for packages matching the given <package spec> list.  If
	no classpath is specified, only the current directory is searched.
  --output-dir <path>
        The directory into which generated HTML files will be placed (the
	directory will be created, if required.  If no output directory is
	specified the default 'apidocs' is used.
    END
  end

  def error(msg)
    $stderr.puts("error: #{msg}")
    exit(-1)
  end

end


CLI.new.main()


# vim:shiftwidth=2:softtabstop=2
