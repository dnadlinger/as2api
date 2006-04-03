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


require 'gettext'

require 'documenter'
require 'getoptlong'
require 'set'
require 'output/html/driver'
require 'api_diff'
require 'output/html/diff'
require 'output/diff/api_dump'
require 'localisation/xliff/driver.rb'
require 'localisation/xliff/translation_loader.rb'

include GetText

bindtextdomain("as2api")

Conf = Struct.new(:output_dir,
                  :classpath,
                  :api_export,
                  :api_name,
                  :api_version,
		  :diff_load_old,
		  :diff_load_new,
		  :diff_url_old,
		  :diff_url_new,
		  :do_diff,
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

# TODO: this is used by other files -- move elsewhere
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
      [ "--api-export",       GetoptLong::NO_ARGUMENT ],
      [ "--api-name",         GetoptLong::REQUIRED_ARGUMENT ],
      [ "--api-version",      GetoptLong::REQUIRED_ARGUMENT ],
      [ "--diff-load-old",    GetoptLong::REQUIRED_ARGUMENT ],
      [ "--diff-load-new",    GetoptLong::REQUIRED_ARGUMENT ],
      [ "--diff-url-old",     GetoptLong::REQUIRED_ARGUMENT ],
      [ "--diff-url-new",     GetoptLong::REQUIRED_ARGUMENT ],
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
    conf.package_filters = []
    conf.draw_diagrams = false
    conf.dot_exe = "dot"  #  i.e. assume 'dot' is in our PATH

    opts.each do |opt, arg|
      case opt
	when "--output-dir"
	  conf.output_dir = File.expand_path(arg)
	when "--classpath"
	  conf.classpath.concat(arg.split(File::PATH_SEPARATOR))
	when "--api-export"
	  conf.api_export = true
	when "--api-name"
	  conf.api_name = arg
	when "--api-version"
	  conf.api_version = arg
	when "--diff-load-old"
	  conf.diff_load_old = arg
	when "--diff-load-new"
	  conf.diff_load_new = arg
	when "--diff-url-old"
	  conf.diff_url_old = arg
	when "--diff-url-new"
	  conf.diff_url_new = arg
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
    if conf.xliff_import && conf.xliff_export
      error(_("Options can't be used together: %s") % "--xliff-import --xliff-export")
    end
    if conf.xliff_export && (conf.source_lang.nil? || conf.target_lang.nil?)
      error(_("Both --source-lang and --target-lang must be provided with --xliff-export"))
    end
    if conf.api_export && (conf.api_name.nil? || conf.api_version.nil?)
      error(_("Both --api-name and --api-version must be provided with --api-export"))
    end
    if conf.diff_load_old.nil? != conf.diff_load_new.nil?
      error(_("--diff-load-old and --diff-load-new must appear together"))
    elsif conf.diff_load_old && conf.diff_load_new
      conf.do_diff = true
    end
    if ARGV.empty? && !conf.do_diff
      usage
      error(_("No packages specified"))
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

  def api_export(type_aggregator)
    generate_api_dump(@conf, type_aggregator)
  end

  def do_api_diff
puts "Loading old API..."
    old_type_agregator, old_api_name, old_api_version = load_api_dump(@conf.diff_load_old)
puts "Loading new API..."
    new_type_agregator, new_api_name, new_api_version = load_api_dump(@conf.diff_load_new)
    if old_api_name != new_api_name
      warn(_("API names differ: #{old_api_name.inspect} #{new_api_name.inspect}"))
    end
    diff = APIDiff.new
puts "Calculating API changes..."
    api_changes = diff.diff(old_type_agregator, new_type_agregator)
    api_changes.api_name = new_api_name
    api_changes.api_old_ver = old_api_version
    api_changes.api_new_ver = new_api_version
    old_type_agregator.each_type { |astype| astype.document = false }
    new_type_agregator.each_type { |astype| astype.document = false }
    old_type_agregator.each_package { |pkg| pkg.doc_base = @conf.diff_url_old }
    new_type_agregator.each_package { |pkg| pkg.doc_base = @conf.diff_url_new }

    generate_diffs(@conf, api_changes)
  end

  def main
    @conf = parse_opts
    if @conf.do_diff
      do_api_diff
    else
      files = find_sources(@conf.classpath)
      error(_("No source files matching specified packages")) if files.empty?
      type_agregator = parse_all(files)
      if @conf.xliff_import
	xliff_import(type_agregator)
      end
      type_resolver = TypeResolver.new(@conf.classpath)
      type_resolver.resolve_types(type_agregator)
      if @conf.api_export
	api_export(type_agregator)
      elsif @conf.xliff_export
	xliff_export(type_agregator)
      else
	document_types(@conf, type_agregator)
      end
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
