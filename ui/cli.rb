# 
# Part of as2api - http://www.badgers-in-foil.co.uk/projects/as2api/
#
# Copyright (c) 2006 David Holroyd, and contributors.
#
# See the file 'COPYING' for terms of use of this code.
#


require 'gettext'

require 'documenter'
require 'getoptlong'
require 'set'
require 'output/html/driver'
require 'output/html/diff'
require 'localisation/xliff/driver.rb'
require 'localisation/xliff/translation_loader.rb'

include GetText

bindtextdomain("as2api")

Conf = Struct.new(:output_dir,
                  :classpath,
                  :oldrev_classpath,
		  :package_filters,
		  :title,
		  :progress_listener,
		  :input_encoding,
		  :draw_diagrams,
		  :dot_exe,
		  :sources,
		  :format_html,
		  :source_lang,
		  :target_lang,
		  :xliff_import,
		  :xliff_export)

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

# allows classes in the default (top-level) namespace
class DefaultPackageFilter
  def matches?(source_file)
    source_file =~ /^[^\/]+$/
  end
end


class VerboseProgressListener < NullProgressListener
  def parsing_sources(total_files)
    @total = total_files
    $stderr.puts(_("Parsing %d source files:") % total_files)
    yield
    progress_bar(total_files)  # ensure we see '100%'
    puts
  end

  def parse_source(file_number, file_name)
    progress_bar(file_number)
  end

  def generating_pages(total_pages)
    @total = total_pages
    $stderr.puts(_("Generating %d HTML pages:") % total_pages)
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
      [ "--oldrev-classpath", GetoptLong::REQUIRED_ARGUMENT ],
      [ "--title",            GetoptLong::REQUIRED_ARGUMENT ],
      [ "--progress",         GetoptLong::NO_ARGUMENT ],
      [ "--encoding",         GetoptLong::REQUIRED_ARGUMENT ],
      [ "--draw-diagrams",    GetoptLong::NO_ARGUMENT ],
      [ "--dot-exe",          GetoptLong::REQUIRED_ARGUMENT ],
      [ "--sources",          GetoptLong::NO_ARGUMENT ],
      [ "--format-html",      GetoptLong::NO_ARGUMENT ],
      [ "--source-lang",      GetoptLong::REQUIRED_ARGUMENT ],
      [ "--target-lang",      GetoptLong::REQUIRED_ARGUMENT ],
      [ "--xliff-import",     GetoptLong::REQUIRED_ARGUMENT ],
      [ "--xliff-export",     GetoptLong::REQUIRED_ARGUMENT ]
    )

    conf = Conf.new
    conf.classpath = []
    conf.oldrev_classpath = []
    conf.package_filters = []
    conf.draw_diagrams = false
    conf.dot_exe = "dot"  #  i.e. assume 'dot' is in our PATH

    opts.each do |opt, arg|
      case opt
	when "--output-dir"
	  conf.output_dir = File.expand_path(arg)
	when "--classpath"
	  conf.classpath.concat(arg.split(File::PATH_SEPARATOR))
	when "--oldrev-classpath"
	  conf.oldrev_classpath.concat(arg.split(File::PATH_SEPARATOR))
	when "--title"
	  conf.title = arg
	when "--help"
	  usage
	  exit(0)
	when "--progress"
	  conf.progress_listener = VerboseProgressListener.new
	when "--encoding"
	  conf.input_encoding = arg
	when "--draw-diagrams"
	  conf.draw_diagrams = true
	when "--dot-exe"
	  conf.dot_exe = arg
	when "--sources"
	  conf.sources = true
	when "--format-html"
	  conf.format_html = true
	when "--source-lang"
	  conf.source_lang = arg
	when "--target-lang"
	  conf.target_lang = arg
	when "--xliff-import"
	  conf.xliff_import = arg
	when "--xliff-export"
	  conf.xliff_export = arg
      end
    end
    if ARGV.empty?
      usage
      error(_("No packages specified"))
    end
    if conf.xliff_import && conf.xliff_export
      error(_("Options can't be used together: %s") % "--xliff-import --xliff-export")
    end
    if conf.xliff_export && (conf.source_lang.nil? || conf.target_lang.nil?)
      error(_("Both --source-lang and --target-lang must be provided with --xliff-export"))
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
      when /\(default\)/i
	DefaultPackageFilter.new
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

  def find_sources(classpath)
    result = []
    ignored_packages = Set.new
    classpath.each do |path|
      found_sources = false
      each_source(File.expand_path(path)) do |source|
	if process_file?(source)
	  result << SourceFile.new(path, source)
	else
	  dirname = File.dirname(source)
	  if ignored_packages.add?(dirname)
	    warn(_("package %s will not be documented") % dirname.gsub(/\//, '.').inspect)
	  end
	end
	found_sources = true
      end
      unless found_sources
	warn(_("%s contains no ActionScript files") % path.inspect)
      end
    end
    result
  end

  def parse_file(file, type_agregator)
    File.open(File.join(file.prefix, file.suffix)) do |io|
      begin
	is_utf8 = detect_bom?(io)
	type = simple_parse(io, file.suffix)
	type.input_file = file
	type.source_utf8 = is_utf8
	type_agregator.add_type(type)
      rescue =>e
	$stderr.puts "#{file.suffix}: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end

  def parse_all(files)
    type_agregator = GlobalTypeAggregator.new
    @conf.progress_listener.parsing_sources(files.length) do
      files.each_with_index do |file, index|
	@conf.progress_listener.parse_source(index, file)
	parse_file(file, type_agregator)
      end
    end
    type_agregator
  end

  def xliff_import(type_aggregator)
    update_docs(@conf, type_aggregator)
  end

  def xliff_export(type_aggregator)
    generate_xliff(@conf, type_aggregator)
  end

  def main
    @conf = parse_opts
    files = find_sources(@conf.classpath)
    error(_("No source files matching specified packages")) if files.empty?
    type_agregator = parse_all(files)
    if @conf.xliff_import
      xliff_import(type_agregator)
    end
    type_resolver = TypeResolver.new(@conf.classpath)
    type_resolver.resolve_types(type_agregator)
    if @conf.xliff_export
      xliff_export(type_agregator)
    else
      document_types(@conf, type_agregator)
    end

    # TODO: remove this hackery
    unless @conf.oldrev_classpath.empty?
      old_files = find_sources(@conf.oldrev_classpath)
      error(_("No source files matching specified packages in oldrev-classpath")) if old_files.empty?
      old_type_agregator = parse_all(old_files, @conf.oldrev_classpath)
      old_type_agregator.resolve_types
      diff = APIDiff.new
      api_changes = diff.diff(old_type_agregator, type_agregator)

      generate_diffs(@conf, api_changes)
    end
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
  --draw-diagrams
        Causes class/interface inheritance diagrams to be generated for each
	package (requires that you have http://www.graphviz.org/).
  --dot-exe <filename>
        Specify the location of the 'dot' tool from Graphviz, if it is not
        available via the standard PATH.
  --sources
        Generate an HTML page for the source code of each input file
    END
  end

  def error(msg)
    $stderr.puts(_("error: %s") % msg)
    exit(-1)
  end

  def warn(msg)
    $stderr.puts(_("warning: %s") % msg)
  end
end


CLI.new.main()


# vim:shiftwidth=2:softtabstop=2
