
require 'documenter'
require 'getoptlong'
require 'html_output'

Conf = Struct.new(:output_dir,
                  :classpath,
		  :package_filters,
		  :title,
		  :progress_listener,
		  :input_encoding)

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


class VerboseProgressListener < NullProgressListener
  def parsing_sources(total_files)
    @total = total_files
    $stderr.puts("Parsing #{total_files} source files:")
    yield
    progress_bar(total_files)  # ensure we see '100%'
    puts
  end

  def parse_source(file_number, file_name)
    progress_bar(file_number)
  end

  def generating_pages(total_pages)
    @total = total_pages
    $stderr.puts("Generating #{total_pages} HTML pages:")
    yield
    progress_bar(total_pages)  # ensure we see '100%'
    puts
  end

  def generate_page(file_number, file_name)
    progress_bar(file_number)
  end

  private

  WIDTH = 38

  def progress_bar(count)
    size = count*WIDTH/@total
    $stderr.print "[#{'='*size}#{' '*(WIDTH-size)}] #{count*100/@total}%\r"
  end
end


class CLI

  def parse_opts
    opts = GetoptLong.new(
      [ "--help",       "-h", GetoptLong::NO_ARGUMENT ],
      [ "--output-dir", "-d", GetoptLong::REQUIRED_ARGUMENT ],
      [ "--classpath",        GetoptLong::REQUIRED_ARGUMENT ],
      [ "--title",            GetoptLong::REQUIRED_ARGUMENT ],
      [ "--progress",         GetoptLong::NO_ARGUMENT ],
      [ "--encoding",         GetoptLong::REQUIRED_ARGUMENT ]
    )

    conf = Conf.new
    conf.classpath = []
    conf.package_filters = []

    opts.each do |opt, arg|
      case opt
	when "--output-dir"
	  conf.output_dir = File.expand_path(arg)
	when "--classpath"
	  conf.classpath.concat(arg.split(File::PATH_SEPARATOR))
	when "--title"
	  conf.title = arg
	when "--help"
	  usage
	  exit(0)
	when "--progress"
	  conf.progress_listener = VerboseProgressListener.new
	when "--encoding"
	  conf.input_encoding = arg
      end
    end
    if ARGV.empty?
      usage
      error("No packages specified")
    end
    ARGV.each do |package_spec|
      conf.package_filters << to_filter(package_spec)
    end

    conf.progress_listener = NullProgressListener.new if conf.progress_listener.nil?
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
	type = simple_parse(io)
	type.input_filename = file.suffix
	type.sourcepath_location(File.dirname(file.suffix))
	type.source_utf8 = is_utf8
	type_agregator.add_type(type)
      rescue =>e
	$stderr.puts "#{file.suffix}: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  def parse_all(files)
    type_agregator = GlobalTypeAggregator.new(@conf.classpath)
    @conf.progress_listener.parsing_sources(files.length) do
      files.each_with_index do |file, index|
	@conf.progress_listener.parse_source(index, file)
	parse_file(file, type_agregator)
      end
    end
    type_agregator
  end

  def main
    @conf = parse_opts
    files = find_sources
    error("No source files matching specified packages") if files.empty?
    type_agregator = parse_all(files)
    type_agregator.resolve_types
    document_types(@conf, type_agregator)
  end

  def usage
    puts <<-END
Usage:
  #{$0} [options] <package spec> ...

Each package spec can be given as:

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
  --progress
	Print feedback showing how far tasks have progressed
  --title <text>
        Put the given text into the titles of generated HTML pages
  --encoding <name>
        The encoding of the source files to be parsed.
    END
  end

  def error(msg)
    $stderr.puts("error: #{msg}")
    exit(-1)
  end

end


CLI.new.main()


# vim:shiftwidth=2:softtabstop=2
