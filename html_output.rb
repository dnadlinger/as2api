
require 'xmlwriter'
require 'xhtmlwriter'
require 'doc_comment'

def link_for_type(type)
  base_path(type.qualified_name.gsub(/\./, "/")+".html")
end

def link_type(out, type, qualified=false)
  href = link_for_type(type)
  if type.instance_of?(ASInterface)
    attr_class = "interface_name"
    attr_title = "Interface #{type.qualified_name}"
  else
    attr_class = "class_name"
    attr_title = "Class #{type.qualified_name}"
  end
  if qualified
    content = type.qualified_name
  else
    content = type.unqualified_name
  end
  out.html_a(content, {"href"=>href,
		       "class"=>attr_class,
		       "title"=>attr_title})
end


def link_for_method(method)
  return "#{link_for_type(method.containing_type)}#method_#{method.name}"
end

def link_method(out, method)
  out.html_a("href"=>link_for_method(method)) do
    out.pcdata(method.name)
    out.pcdata("()")
  end
end

$base_path = ""
$path = ""

def base_path(file)
  "#{$base_path}#{file}"
end

def in_subdir(path)
  save_path = $path
  save_base_path = $base_path.dup
  path = path.split(File::SEPARATOR)
  if path.first == ""
    path.shift
    $path = "/"
  end
  path.each do |part|
    if $path == ""
      $path = part
    else
      $base_path << ".."+File::SEPARATOR
      $path = File.join($path, part)
    end
    unless FileTest.exist?($path)
      Dir.mkdir($path)
    end
  end
  yield
  $path = save_path
  $base_path = save_base_path
end

def write_file(name)
  File.open(File.join($path, name), "w") do |io|
    yield io
  end
end

def create_page(page)
  in_subdir(page.path_name) do
    write_file("#{page.base_name}.html") do |io|
      page.generate(XMLWriter.new(io))
    end
  end
end

def document_member?(member)
  !member.access.private?
end


# accessability; make a link to skip over the (navigation) elements produced
# by the given block
def skip_nav(out)
  out.html_div do
    out.html_a("", {"href"=>"#skip_nav", "title"=>"Skip navigation"})
  end
  yield
  out.html_div do
    out.html_a("", {"name"=>"skip_nav"})
  end
end

PROJECT_PAGE = "http://www.badgers-in-foil.co.uk/projects/as2api/"

class Page
  include XHTMLWriter

  def initialize(path_name, base_name)
    @path_name = path_name
    @base_name = base_name
    @encoding = "iso-8859-1"
    @doctype_id = :strict
    @title = nil
    @io = nil  # to be set during the lifetime of generate() call
  end

  attr_accessor :path_name, :base_name, :encoding, :doctype_id, :title


  def generate(xml_writer)
    @io = xml_writer
    pi("xml version=\"1.0\" encoding=\"#{encoding}\"") unless encoding.nil?
    case doctype_id
    # FIXME: push this code down into XHTMLWriter, and have it switch the
    # allowed elements depending on the value passed at construction
    when :strict
      doctype("html", "PUBLIC",
              "-//W3C//DTD XHTML 1.0 Strict//EN",
	      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd")
    when :transitional
      doctype("html", "PUBLIC",
              "-//W3C//DTD XHTML 1.0 Transitionalt//EN",
	      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
    when :frameset
      doctype("html", "PUBLIC",
              "-//W3C//DTD XHTML 1.0 Frameset//EN",
	      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd")
    else
      raise "unhandled doctype #{doctype_id.inspect}"
    end
    html_html do
      generate_head
      generate_content
    end
  end

  def generate_head
    html_head do
      html_title(title) unless title.nil?
      html_link("rel"=>"stylesheet",
		       "type"=>"text/css",
		       "href"=>base_path("style.css"))
      html_meta("name"=>"generator", "content"=>PROJECT_PAGE)
    end
  end
end

class BasicPage < Page
  def generate_content
    html_body do
      skip_nav(self) do
	navigation
      end
      generate_body_content
      navigation
      generate_footer
    end
  end

  def generate_footer
    html_div("class"=>"footer") do
      html_a("as2api", {"href"=>PROJECT_PAGE, "title"=>"ActionScript 2 API Documentation Generator"})
    end
  end
end

class TypePage < BasicPage

  def initialize(path_name, type)
    super(path_name, type.unqualified_name)
    @type = type
    if @type.source_utf8
      @encoding = "utf-8"
    else
      @encoding = "iso-8859-1"
    end
    @title = type.qualified_name
  end

  def generate_body_content
      if @type.instance_of?(ASClass)
	html_h1("Class "+@type.qualified_name)
      elsif @type.instance_of?(ASInterface)
	html_h1("Interface "+@type.qualified_name)
      end

      type_hierachy(@type)

      if @type.implements_interfaces?
	html_div("class"=>"interfaces") do
	  html_h2("Implemented Interfaces")
	  @type.each_interface do |interface|
	    # TODO: need to resolve interface name, make links
	    html_code do
	      link_type_proxy(interface)
	    end
	    pcdata(" ")
	  end
	end
      end
      html_div("class"=>"type_description") do
	if @type.comment
	  comment_data = @type.comment

	  html_h2("Description")
	  html_p do
	    output_doccomment_blocktag(comment_data[0])
	  end
	  if comment_has_seealso?(comment_data)
	    html_h4("See Also")
	    html_ul("class"=>"extra_info") do
	      comment_each_seealso(comment_data) do |see_comment|
		html_li do
		  output_doccomment_blocktag(see_comment)
		end
	      end
	    end
	  end
	end
      end
      
      field_index_list(@type) if @type.inherited_fields?
      method_index_list(@type) if @type.methods?
      constructor_detail(@type) if @type.constructor? && document_member?(@type.constructor)
      field_detail_list(@type) if @type.fields?
      method_detail_list(@type) if @type.methods?
  end

  def navigation
    html_ul("class"=>"main_nav") do
      html_li do
	html_a("Overview", {"href"=>base_path("overview-summary.html")})
      end
      html_li do
	html_a("Package", {"href"=>"package-summary.html"})
      end
      html_li do
	html_span("Class", {"class"=>"nav_current"})
      end
      html_li do
	html_a("Index", {"href"=>base_path("index-files/index.html")})
      end
    end
  end

  def field_index_list(type)
    html_div("class"=>"field_index") do
      html_h2("Field Index")
      list_fields(type)
      if type.has_ancestor?
	type.each_ancestor do |type|
	  if type.fields?
	    html_h4 do
	      pcdata("Inherited from ")
	      link_type(type)
	    end
	    html_p("class"=>"extra_info") do
	      list_fields(type, link_for_type(type))
	    end
	  end
	end
      end
    end
  end

  def list_fields(type, href_prefix="")
    fields = type.fields.sort
    index = 0
    fields.each do |field|
      next unless document_member?(field)
      pcdata(", ") if index > 0
      html_code do
	html_a("href"=>"#{href_prefix}#field_#{field.name}") do
	  pcdata(field.name)
	end
      end
      index += 1
    end
  end

  def method_index_list(type)
    html_div("class"=>"method_index") do
      html_h2("Method Index")
      if type.constructor? && document_member?(type.constructor)
	html_p do
	  html_code do
	    pcdata("new ")
	      html_a("href"=>"#method_#{type.constructor.name}") do
		pcdata(type.constructor.name+"()")
	      end
	  end
	end
      end
      known_method_names = []
      list_methods(type, known_method_names)
      if type.has_ancestor?
	type.each_ancestor do |type|
	  if type.methods?
	    html_h4 do
	      pcdata("Inherited from ")
	      link_type(self, type)
	    end
	    html_p("class"=>"extra_infp") do
	      list_methods(type, known_method_names, link_for_type(type))
	    end
	  end
	end
      end
    end
  end

  def list_methods(type, known_method_names, href_prefix="")
    methods = type.methods.select do |method|
      !known_method_names.include?(method.name) && document_member?(method)
    end
    methods.sort!
    methods.each_with_index do |method, index|
      known_method_names << method.name
      pcdata(", ") if index > 0
      html_a("href"=>"#{href_prefix}#method_#{method.name}") do
	pcdata(method.name+"()")
      end
    end
  end

  def constructor_detail(type)
    html_div("class"=>"constructor_detail_list") do
      html_h2("Constructor Detail")
      document_method(type.constructor)
    end
  end

  def field_detail_list(type)
    html_div("class"=>"field_detail_list") do
      html_h2("Field Detail")
      type.each_field do |field|
	document_field(field) if document_member?(field)
      end
    end
  end

  def document_field(field)
    html_a("name"=>"field_#{field.name}")
    html_h3(field.name)
    html_div("class"=>"field_details") do
      field_synopsis(field)
      if field.comment
	html_div("class"=>"field_info") do
	  comment_data = field.comment
	  output_doccomment_blocktag(comment_data[0])
	  if comment_has_field_additional_info?(comment_data)
	    if comment_has_seealso?(comment_data)
	      document_seealso(comment_data)
	    end
	  end
	end
      end
    end
  end

  def method_detail_list(type)
    html_div("class"=>"method_detail_list") do
      html_h2("Method Detail")
      count = 0
      type.each_method do |method|
	next unless document_member?(method)
	document_method(method, count%2==0)
	count += 1
      end
    end
  end

  def document_method(method, alt_row=false)
    css_class = "method_details"
    css_class << " alt_row" if alt_row
    html_div("class"=>css_class) do
      html_a("name"=>"method_#{method.name}")
      html_h3(method.name)
      method_synopsis(method)
      if method.comment
	html_div("class"=>"method_info") do
	  comment_data = method.comment
	  html_p do
	    output_doccomment_blocktag(comment_data[0])
	  end
	  if method_additional_info?(method, comment_data)
	    # TODO: assumes that params named in docs match formal arguments
	    #       should really filter out those that don't match before this
	    #       test
	    if comment_has_params?(comment_data)
	      document_parameters(method.arguments, comment_data)
	    end
	    if comment_has_return?(comment_data)
	      document_return(comment_data)
	    end
	    if comment_has_exceptions?(comment_data)
	      document_exceptions(comment_data)
	    end
	    if method.containing_type.is_a?(ASClass)
	      spec_method = method.specified_by
	      unless spec_method.nil?
		document_specified_by(spec_method)
	      end
	    end
	    if comment_has_seealso?(comment_data)
	      document_seealso(comment_data)
	    end
	  end
	end
      else
	if method.containing_type.is_a?(ASClass)
	  spec_method = method.specified_by
	  unless spec_method.nil?
	    html_div("class"=>"method_info") do
	      document_specified_by(spec_method)
	    end
	  end
	end
      end
    end
  end

  def type_hierachy(type)
    # TODO: ASCII art is an accessability problem.  Replace with images that
    #       have alt-text, or use CSS to generate content, e.g.
    #          <span class="inherit_relation" title="inherited by"></span>
    html_pre("class"=>"type_hierachy") do
      count = 0
      unless type.extends.nil?
	count = type_hierachy_recursive(type.extends)
      end
      if count > 0
	pcdata("   " * count)
	pcdata("+--")
      end
      html_strong(type.qualified_name)
    end
  end

  def type_hierachy_recursive(type_proxy)
    count = 0
    if type_proxy.resolved?
      type = type_proxy.resolved_type
      unless type.extends.nil?
	count = type_hierachy_recursive(type.extends)
      end
    else
      pcdata("????\n")
      count = 1
    end
    if count > 0
      pcdata("   " * count)
      pcdata("+--")
    end
    link_type_proxy(type_proxy, true)
    pcdata("\n")
    return count + 1
  end

  def document_parameters(arguments, comment_data)
    html_h4("Parameters")
    html_table("class"=>"arguments extra_info", "summary"=>"") do
      arguments.each do |arg|
	desc = comment_find_param(comment_data, arg.name)
	if desc
	  html_tr do
	    html_td do
	      html_code(arg.name)
	    end
	    html_td do
	      output_doccomment_blocktag(desc)
	    end
	  end
	end
      end
    end
  end

  def document_return(comment_data)
    html_h4("Return")
    return_comment = comment_find_return(comment_data)
    html_p("class"=>"extra_info") do
      output_doccomment_blocktag(return_comment)
    end
  end

  def document_exceptions(comment_data)
    html_h4("Throws")
    html_table("class"=>"exceptions extra_info", "summary"=>"") do
      comment_each_exception(comment_data) do |exception_comment|
	html_tr do
	  html_td do
	    link_type_proxy(exception_comment.exception_type)
	  end
	  html_td do
	    output_doccomment_blocktag(exception_comment)
	  end
	end
      end
    end
  end

  def document_seealso(comment_data)
    html_h4("See Also")
    html_ul("class"=>"extra_info") do
      comment_each_seealso(comment_data) do |see_comment|
	html_li do
	  output_doccomment_blocktag(see_comment)
	end
      end
    end
  end

  def document_specified_by(method)
    html_h4("Specified By")
    html_p("class"=>"extra_info") do
      link_method(self, method)
      pcdata(" in ")
      link_type(self, method.containing_type, true)
    end
  end

  def method_additional_info?(method, comment_data)
    if method.containing_type.is_a?(ASClass)
      spec_method = method.specified_by
    else
      spec_method = nil
    end
    return comment_has_method_additional_info?(comment_data) || !spec_method.nil?
  end

  def output_doccomment_blocktag(block)
    block.each_inline do |inline|
      output_doccomment_inlinetag(inline)
    end
  end

  def output_doccomment_inlinetag(inline)
    if inline.is_a?(String)
      pcdata(inline)
    elsif inline.is_a?(LinkTag)
      link_type_proxy(inline.target)
    else
      html_em(inline.inspect)
    end
  end

  def method_synopsis(method)
    html_code("class"=>"method_synopsis") do
      if method.access.is_static
	pcdata("static ")
      end
      unless method.access.visibility.nil?
	pcdata("#{method.access.visibility.body} ")
      end
      pcdata("function ")
      html_strong("class"=>"method_name") do
	pcdata(method.name)
      end
      pcdata("(")
      method.arguments.each_with_index do |arg, index|
	pcdata(", ") if index > 0
	pcdata(arg.name)
	if arg.arg_type
	  pcdata(":")
	  link_type_proxy(arg.arg_type)
	end
      end
      pcdata(")")
      if method.return_type
	pcdata(":")
	link_type_proxy(method.return_type)
      end
    end
  end

  def field_synopsis(field)
    html_code("class"=>"field_synopsis") do
      if field.instance_of?(ASImplicitField)
	implicit_field_synopsis(field)
      else
	explicit_field_synopsis(field)
      end
    end
  end

  def explicit_field_synopsis(field)
    if field.access.is_static
      pcdata("static ")
    end
    unless field.access.visibility.nil?
      pcdata("#{field.access.visibility.body} ")
    end
    html_strong("class"=>"field_name") do
      pcdata(field.name)
    end
    if field.field_type
      pcdata(":")
      link_type_proxy(field.field_type)
    end
  end

  def implicit_field_synopsis(field)
    if field.access.is_static
      pcdata("static ")
    end
    unless field.access.visibility.nil?
      pcdata("#{field.access.visibility.body} ")
    end
    html_strong("class"=>"field_name") do
      pcdata(field.name)
    end
    field_type = field.field_type
    unless field_type.nil?
      pcdata(":")
      link_type_proxy(field_type)
    end
    unless field.readwrite?
      pcdata(" ")
      html_em("class"=>"read_write_only") do
	if field.read?
	  pcdata("[Read Only]")
	else
	  pcdata("[Write Only]")
	end
      end
    end
  end

  def link_type_proxy(type_proxy, qualified=false)
    if type_proxy.resolved? && type_proxy.resolved_type.document?
      link_type(self, type_proxy.resolved_type, qualified)
    else
      if type_proxy.resolved?
	if type_proxy.resolved_type.instance_of?(ASInterface)
	  html_span(type_proxy.local_name, {"class"=>"interface_name"})
	else
	  html_span(type_proxy.local_name, {"class"=>"class_name"})
	end
      else
	html_span(type_proxy.local_name, {"class"=>"unresolved_type_name"})
      end
    end
  end


  # TODO: All these comment_*() methods obviously want to belong to some new
  #       class, as yet unwritten.

  def comment_each_block_of_type(comment_data, type)
    comment_data.each_block do |block|
      yield block if block.is_a?(type)
    end
  end

  def comment_has_blocktype?(comment_data, type)
    comment_each_block_of_type(comment_data, type) do |block|
      return true
    end
    return false
  end

  def comment_has_params?(comment_data)
    return comment_has_blocktype?(comment_data, ParamBlockTag)
  end

  def comment_has_exceptions?(comment_data)
    return comment_has_blocktype?(comment_data, ThrowsBlockTag)
  end

  def comment_has_seealso?(comment_data)
    return comment_has_blocktype?(comment_data, SeeBlockTag)
  end

  def comment_has_return?(comment_data)
    return comment_has_blocktype?(comment_data, ReturnBlockTag)
  end

  # Does the method comment include any info in addition to any basic
  # description block?
  def comment_has_method_additional_info?(comment_data)
    return comment_has_params?(comment_data) ||
	   comment_has_return?(comment_data) ||
	   comment_has_exceptions?(comment_data) ||
	   comment_has_seealso?(comment_data)
  end

  # Does the field comment include any info in addition to any basic description
  # block?
  def comment_has_field_additional_info?(comment_data)
    return comment_has_seealso?(comment_data)
  end

  def comment_each_exception(comment_data)
    comment_data.each_block do |block|
      yield block if block.is_a?(ThrowsBlockTag)
    end
  end

  def comment_each_seealso(comment_data)
    comment_each_block_of_type(comment_data, SeeBlockTag) do |block|
      yield block
    end
  end

  def comment_find_param(comment_data, param_name)
    comment_each_block_of_type(comment_data, ParamBlockTag) do |block|
      return block if block.param_name == param_name
    end
    return nil
  end

  def comment_find_return(comment_data)
    comment_each_block_of_type(comment_data, ReturnBlockTag) do |block|
      return block
    end
    return nil
  end

end


def package_dir_for(package)
  package.name.gsub(/\./, "/")
end

def package_display_name_for(package)
  return "(Default)" if package.name == ""
  package.name
end

def package_link_for(package, page)
  return page if package.name == ""
  package_dir_for(package) + "/" + page
end



class PackageIndexPage < BasicPage

  def initialize(path_name, package)
    super(path_name, "package-summary")
    @package = package
    @title = "Package #{package_display_name_for(@package)} API Documentation"
  end

  def generate_body_content
      html_h1("Package "+package_display_name_for(@package))
      interfaces = @package.interfaces
      unless interfaces.empty?
	interfaces.sort!
	html_table("class"=>"summary_list", "summary"=>"") do
	  html_tr do
	    html_th("Interface Summary")
	  end
	  interfaces.each do |type|
	    html_tr do
	
	      html_td do
		html_a(type.unqualified_name, {"href"=>type.unqualified_name+".html"})
	      end
	      #html_td do
		# TODO: package description
	      #end
	    end
	  end
	end
      end
      classes = @package.classes
      unless classes.empty?
	classes.sort!
	html_table("class"=>"summary_list", "summary"=>"") do
	  html_tr do
	    html_th("Class Summary")
	  end
	  classes.each do |type|
	    html_tr do
	
	      html_td do
		html_a(type.unqualified_name, {"href"=>type.unqualified_name+".html"})
	      end
	      #html_td do
		# TODO: package description
	      #end
	    end
	  end
	end
      end
  end

  def navigation
    html_ul("class"=>"main_nav") do
      html_li do
	html_a("Overview", {"href"=>base_path("overview-summary.html")})
      end
      html_li do
	html_span("Package", {"class"=>"nav_current"})
      end
      html_li do
	html_span("Class")
      end
      html_li do
	html_a("Index", {"href"=>base_path("index-files/index.html")})
      end
    end
  end

end


class PackageFramePage < Page

  def initialize(path_name, package)
    super(path_name, "package-frame")
    @package = package
    @title = "Package #{package_display_name_for(@package)} API Naviation"
    @doctype_id = :transitional
  end

  def generate_content
      html_body do
	html_p do
	  html_a(package_display_name_for(@package), {"href"=>"package-summary.html", "target"=>"type_frame"})
	end
	interfaces = @package.interfaces
	unless interfaces.empty?
	  interfaces.sort!
	  html_h3("Interfaces")
	  html_ul("class"=>"navigation_list") do
	    interfaces.each do |type|
	  
	      html_li do
		html_a(type.unqualified_name, {"href"=>type.unqualified_name+".html", "target"=>"type_frame", "title"=>type.qualified_name})
	      end
	    end
	  end
	end
	classes = @package.classes
	unless classes.empty?
	  classes.sort!
	  html_h3("Classes")
	  html_ul("class"=>"navigation_list") do
	    classes.each do |type|
	  
	      html_li do
		html_a(type.unqualified_name, {"href"=>type.unqualified_name+".html", "target"=>"type_frame", "title"=>type.qualified_name})
	      end
	    end
	  end
	end
      end
  end

end

class OverviewPage < BasicPage
  def initialize(path_name, type_agregator)
    super(path_name, "overview-summary")
    @type_agregator = type_agregator
    @title = "API Overview"
  end

  def generate_body_content
      html_h1("API Overview")
      html_table("class"=>"summary_list", "summary"=>"") do
	html_tr do
	  html_th("Packages")
	end
	packages = @type_agregator.packages.sort
	packages.each do |package|
	  html_tr do
      
	    html_td do
	      name = package_display_name_for(package)
	      html_a(name, {"href"=>package_link_for(package, "package-summary.html")})
	    end
	    #html_td do
	      # TODO: package description
	    #end
	  end
	end
      end
  end

  def navigation
    html_ul("class"=>"main_nav") do
      html_li do
	html_span("Overview", {"class"=>"nav_current"})
      end
      html_li do
	html_span("Package")
      end
      html_li do
	html_span("Class")
      end
      html_li do
	html_a("Index", {"href"=>"index-files/index.html"})
      end
    end
  end

end


class OverviewFramePage < Page

  def initialize(path_name, type_agregator)
    super(path_name, "overview-frame")
    @type_agregator = type_agregator
    @title = "API Overview"
    @doctype_id = :transitional
  end

  def generate_content
      html_body do
	html_h3("Packages")
	html_ul("class"=>"navigation_list") do
	
	  html_li do
	    html_a("(All Types)", {"href"=>"all-types-frame.html", "target"=>"current_package_frame"})
	  end
	  packages = @type_agregator.packages.sort
	  packages.each do |package|
	
	    html_li do
	      name = package_display_name_for(package)
	      
	      html_a(name, {"href"=>package_link_for(package, "package-frame.html"), "target"=>"current_package_frame", "title"=>name})
	    end
	  end
	end
      end
  end

end


def package_list(path_name, type_agregator)
  # REVISIT: Will a package list actually be useful for ActionScript, or can
  #          we always assume that any code that makes reference to a type
  #          must have access to that type's source in order to compile?
  #          (In theory, this file will allow javadoc to link to ActionScript
  #          classes, so maybe keep it just for that.)
  in_subdir(path_name) do
    write_file("package-list") do |out|
      type_agregator.each_package do |package|
	out.puts(package.name) unless package.name == ""
      end
    end
  end
end


class AllTypesFramePage < Page

  def initialize(path_name, type_agregator)
    super(path_name, "all-types-frame")
    @type_agregator = type_agregator
    @title = "as2api"
    @doctype_id = :transitional
  end

  def generate_content
      html_body do
	html_h3("All Types")
	html_ul("class"=>"navigation_list") do
	  types = @type_agregator.types.sort do |a,b|
	    cmp = a.unqualified_name.downcase <=> b.unqualified_name.downcase
	    if cmp == 0
	      a.qualified_name <=> b.qualified_name
	    else
	      cmp
	    end
	  end
	  types.each do |type|
	    if type.document?
	      href = type.qualified_name.gsub(/\./, "/") + ".html"
	      html_li do
		html_a(type.unqualified_name, {"href"=>href, "title"=>type.qualified_name, "target"=>"type_frame"})
	      end
	    end
	  end
	end
      end
  end

end


class FramesetPage < Page

  def initialize(path_name)
    super(path_name, "frameset")
    @title = "as2api"
    @doctype_id = :frameset
  end

  def generate_content
    html_frameset("cols"=>"20%,80%") do
      html_frameset("rows"=>"30%,70%") do
	html_frame("src"=>"overview-frame.html",
	                  "name"=>"all_packages_frame",
	                  "title"=>"All Packages")
	html_frame("src"=>"all-types-frame.html",
	                  "name"=>"current_package_frame",
                          "title"=>"All types")
      end
      html_frame("src"=>"overview-summary.html",
                        "name"=>"type_frame",
                        "title"=>"Package and type descriptions")
      html_noframes do
	html_body do
	  html_a("Non-frameset overview page", {"href"=>"overview-summary.html"})
	end
      end
    end
  end
end

class IndexTerm
  def <=>(other)
    cmp = term.downcase <=> other.term.downcase
    cmp = term <=> other.term if cmp == 0
    cmp
  end
end

class TypeIndexTerm < IndexTerm
  def initialize(astype)
    @astype = astype
  end

  def term
    @astype.unqualified_name
  end

  def link(out)
    link_type(out, @astype)
    out.pcdata(" in package ")
    out.html_a(@astype.package_name, {"href"=>"../" + @astype.package_name.gsub(".", "/") + "/package-summary.html"})
  end
end

class MemberIndexTerm < IndexTerm
  def initialize(astype, asmember)
    @astype = astype
    @asmember = asmember
  end

  def term
    @asmember.name
  end
end

class MethodIndexTerm < MemberIndexTerm
  def link(out)
    link_method(out, @asmember)
    out.pcdata(" method in ")
    link_type(out, @astype, true)
  end
end

class FieldIndexTerm < MemberIndexTerm
  def link(out)
    href_prefix = link_for_type(@astype)
    out.html_a("href"=>"#{href_prefix}#field_#{@asmember.name}") do
      out.pcdata(@asmember.name)
    end
    out.pcdata(" field in ")
    link_type(out, @astype, true)
  end
end

class IndexPage < BasicPage
  def initialize(path_name, type_agregator)
    super(path_name, "index")
    @type_agregator = type_agregator
    @title = "Alphabetical Index"
  end

  def create_index()
    index = []
    # TODO: include packages
    @type_agregator.each_type do |astype|
      if astype.document?
	index << TypeIndexTerm.new(astype)
	astype.each_method do |asmethod|
	  if document_member?(asmethod)
	    index << MethodIndexTerm.new(astype, asmethod)
	  end
	end
	if astype.is_a?(ASClass)
	  astype.each_field do |asfield|
	    if document_member?(asfield)
	      index << FieldIndexTerm.new(astype, asfield)
	    end
	  end
	end
      end
    end

    index.sort!
  end

  def generate_body_content
    index = create_index()

    index.each do |element|
      html_p do
	element.link(self)
      end
    end
  end

  def navigation
    html_ul("class"=>"main_nav") do
      html_li do
	html_a("Overview", {"href"=>base_path("overview-summary.html")})
      end
      html_li do
	html_span("Package")
      end
      html_li do
	html_span("Class")
      end
      html_li do
	html_span("Index", {"class"=>"nav_current"})
      end
    end
  end

end

def make_page_list(output_path, type_agregator)
  list = []

  list << FramesetPage.new(output_path)
  list << OverviewPage.new(output_path, type_agregator)
  list << OverviewFramePage.new(output_path, type_agregator)
  list << AllTypesFramePage.new(output_path, type_agregator)

  # packages..
  type_agregator.each_package do |package|
    dir = File.join(output_path, package_dir_for(package))
    list << PackageIndexPage.new(dir, package)
    list << PackageFramePage.new(dir, package)
  end

  # types..
  type_agregator.each_type do |type|
    if type.document?
      dir = File.join(output_path, type.package_name.gsub(/\./, "/"))
      list << TypePage.new(dir, type)
    end
  end

  dir = File.join(output_path, "index-files")
  list << IndexPage.new(dir, type_agregator)

  list
end

def create_all_pages(list)
  list.each do |page|
    create_page(page)
  end
end

def document_types(output_path, type_agregator)
  list = make_page_list(output_path, type_agregator)
  create_all_pages(list)
  package_list(output_path, type_agregator)
end

# vim:softtabstop=2:shiftwidth=2

