
require 'xmlwriter'
require 'xhtmlwriter'
require 'doc_comment'
require 'rexml/document'

def stylesheet(output_dir)
  name = "style.css"

  # avoid overwriting a (possibly modified) existing stylesheet
  return if FileTest.exist?(File.join(output_dir, name))

  write_file(output_dir, name) do |out|
    out.print <<-HERE
h1, h2, h3, h4 th {
	font-family: sans-serif;
}

h2 {
	background-color: #ccccff;
	padding-left: .2em;
	padding-right: .2em;
	-moz-border-radius: .2em;
}

h4 {
	margin: 0;
}

.extra_info {
	padding-left: 2em;
	margin: 0;
}

.method_details, .field_details {
	padding-bottom: .5em;
}

.method_info, .field_info {
	padding-left: 3em;
}

.alt_row {
	background-color: #eeeeee;
}

.main_nav {
	background-color: #EEEEFF;
	padding: 4px;
}
.main_nav li {
	font-family: sans-serif;
	font-weight: bolder;
	display: inline;
}
.main_nav li * {
	padding: 4px;
}
.nav_current {
	background-color: #00008B;
	color: #FFFFFF;
}

table.summary_list {
	border-collapse: collapse;
	width: 100%;
	margin-bottom: 1em;
}
table.summary_list th {
	background-color: #CCCCFF;
	font-size: larger;
}
table.summary_list td, table.summary_list th {
	border: 2px solid grey;
	padding: .2em;
}
ul.navigation_list {
	padding-left: 0;
}
ul.navigation_list li {
	margin: 0 0 .4em 0;
	list-style: none;
}

table.exceptions td, table.arguments td {
	vertical-align: text-top;
	padding: 0 1em .5em 0;
}

/*
.unresolved_type_name {
	background-color: red;
	color: white;
}
*/

.interface_name {
	font-style: italic;
}

.footer {
	text-align: center;
	font-size: smaller;
}
/*
.read_write_only {
}
*/
.diagram {
	text-align: center;
}
    HERE
  end
end


def ensure_dir(path)
  path_components = path.split(File::SEPARATOR)
  base_path = nil
  if path_components.first == ""
    path_components.shift
    base_path = "/"
  end
  path_components.each do |part|
    if base_path.nil?
      base_path = part
    else
      base_path = File.join(base_path, part)
    end
    unless FileTest.exist?(base_path)
      Dir.mkdir(base_path)
    end
  end
end

def write_file(path, name)
  ensure_dir(path)
  name = File.join(path, name)
  File.open(name, "w") do |io|
    yield io
  end
end

def create_page(output_dir, page)
  dir = File.join(output_dir, page.path_name)
  write_file(dir, "#{page.base_name}.html") do |io|
    page.generate(XMLWriter.new(io))
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

  def initialize(base_name, path_name=nil)
    @path_name = path_name
    @base_name = base_name
    @encoding = nil
    @doctype_id = :strict
    @title = nil
    @title_extra = nil
    @io = nil  # to be set during the lifetime of generate() call
  end

  attr_accessor :path_name, :base_name, :encoding, :doctype_id, :title_extra

  attr_writer :title

  def title
    if @title_extra
      if @title
	"#{@title} - #{@title_extra}"
      else
	@title_extra
      end
    else
      @title
    end
  end

  def generate(xml_writer)
    @io = xml_writer
    if encoding.nil?
      pi("xml version=\"1.0\"")
    else
      pi("xml version=\"1.0\" encoding=\"#{encoding}\"")
    end
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
      unless encoding.nil?
        html_meta("http-equiv"=>"Content-Type",
	          "content"=>"text/html; charset=#{encoding}")
      end
    end
  end

  def link_for_type(type)
    base_path(type.qualified_name.gsub(/\./, "/")+".html")
  end

  def link_type(type, qualified=false)
    attrs = {}
    if type.instance_of?(ASInterface)
      attrs["class"] = "interface_name"
      attrs["title"] = "Interface #{type.qualified_name}"
    elsif type.instance_of?(ASClass)
      attrs["class"] = "class_name"
      attrs["title"] = "Class #{type.qualified_name}"
    elsif type == AS_VOID
      attrs["class"] = "void_name"
    end
    if qualified
      content = type.qualified_name
    else
      content = type.unqualified_name
    end
    if type.document?
      attrs["href"] = link_for_type(type)
      html_a(content, attrs)
    else
      html_span(content, attrs)
    end
  end


  def link_for_method(method)
    return "#{link_for_type(method.containing_type)}#method_#{method.name}"
  end

  def link_method(method)
    if method.containing_type.document?
      html_a("href"=>link_for_method(method)) do
	pcdata(method.name)
	pcdata("()")
      end
    else
      pcdata(method.name)
      pcdata("()")
    end
  end

  def base_path(file)
    return file if @path_name.nil?
    ((".."+File::SEPARATOR) * @path_name.split(File::SEPARATOR).length) + file
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

  def initialize(type)
    dir = type.package_name.gsub(/\./, "/")
    super(type.unqualified_name, dir)
    @type = type
    if @type.source_utf8
      @encoding = "utf-8"
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
      
      field_index_list(@type) if @type.fields? && @type.inherited_fields?
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
	if type.document?
	  html_a("href"=>"#{href_prefix}#field_#{field.name}") do
	    pcdata(field.name)
	  end
	else
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
	      link_type(type)
	    end
	    html_p("class"=>"extra_info") do
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
      if type.document?
	html_a("href"=>"#{href_prefix}#method_#{method.name}") do
	  pcdata(method.name+"()")
	end
      else
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
      html_div("class"=>"method_info") do
	if method.comment
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
	    method_info_from_supertype(method)
	    if comment_has_seealso?(comment_data)
	      document_seealso(comment_data)
	    end
	  end
	else
	  method_info_from_supertype(method)
	end
      end
    end
  end

  def method_info_from_supertype(method)
    if method.containing_type.is_a?(ASClass)
      spec_method = method.specified_by
      unless spec_method.nil?
	document_specified_by(spec_method)
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
      link_method(method)
      pcdata(" in ")
      link_type(method.containing_type, true)
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
      passthrough(inline)  # allow HTML through unabused (though I wish it were
                           # easy to require it be valid XHTML)
    elsif inline.is_a?(LinkTag)
      if inline.target && inline.member
	if inline.target.resolved?
	  href = link_for_type(inline.target.resolved_type)
	  if inline.member =~ /\(/
	    target = "#method_#{$`}"
	  else
	    target = "#field_#{inline.member}"
	  end
	  href << target
	  html_a("href"=>href) do
	    pcdata("#{inline.target.name}.#{inline.member}")
	  end
	else
	  pcdata("#{inline.target.name}##{inline.member}")
	end
      elsif inline.target
	link_type_proxy(inline.target)
      else
	if inline.member =~ /\(/
	  target = "#method_#{$`}"
	else
	  target = "#field_#{inline.member}"
	end
	html_a("href"=>target) do
	  pcdata(inline.member)
	end
      end
    elsif inline.is_a?(CodeTag)
      html_code do
	pcdata(inline.text)
      end
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
    if type_proxy.resolved?
      link_type(type_proxy.resolved_type, qualified)
    else
      html_span(type_proxy.local_name, {"class"=>"unresolved_type_name"})
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

  def initialize(conf, package)
    dir = package_dir_for(package)
    super("package-summary", dir)
    @package = package
    @title = "Package #{package_display_name_for(@package)} API Documentation"
    @conf = conf
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

    if @conf.draw_diagrams
      draw_package_diagrams
      class_diagram
      interface_diagram
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

  def class_diagram
    dir = File.join(@conf.output_dir, path_name)
    if FileTest.exists?(File.join(dir, "package-classes.png"))
      html_h1("Class Inheritance Diagram")
      html_div("class"=>"diagram") do
	if FileTest.exists?(File.join(dir, "package-classes.cmapx"))
	  map = true
	  File.open(File.join(dir, "package-classes.cmapx")) do |io|
	    copy_xml(io, @io)
	  end
	else
	  map = false
	end
	attr = {"src"=>"package-classes.png"}
	attr["usemap"] = "class_diagram" if map
        html_img(attr)
      end
    end
  end

  def interface_diagram
    dir = File.join(@conf.output_dir, path_name)
    if FileTest.exists?(File.join(dir, "package-interfaces.png"))
      html_h1("Interface Inheritance Diagram")
      html_div("class"=>"diagram") do
	if FileTest.exists?(File.join(dir, "package-interfaces.cmapx"))
	  map = true
	  File.open(File.join(dir, "package-interfaces.cmapx")) do |io|
	    copy_xml(io, @io)
	  end
	else
	  map = false
	end
	attr = {"src"=>"package-interfaces.png"}
	attr["usemap"] = "interface_diagram" if map
        html_img(attr)
      end
    end
  end

  def draw_package_diagrams
    asclasses = @package.classes
    dir = File.join(@conf.output_dir, path_name)
    unless asclasses.empty?
      write_file(dir, "classes.dot") do |io|
	io.puts("strict digraph class_diagram {")
	  io.puts("  rankdir=LR;")
	   asclasses.each do |astype|
	    io.puts("  #{astype.unqualified_name}[")
	    io.puts("    label=\"#{astype.unqualified_name}\",")
	    io.puts("    URL=\"#{astype.unqualified_name}.html\",")
	    io.puts("    tooltip=\"#{astype.qualified_name}\",")
	    io.puts("    fontname=\"Times-Italic\",") if astype.is_a?(ASInterface)
	    io.puts("    shape=\"record\"")
	    io.puts("  ];")
	  end
	  asclasses.each do |astype|
	    parent = astype.extends
	    if !parent.nil? && parent.resolved?
	      if parent.resolved_type.package_name == @package.name
		io.puts("  #{parent.resolved_type.unqualified_name} -> #{astype.unqualified_name};")
	      end
	    end
	  end
	io.puts("}")
      end
      system(@conf.dot_exe, "-Tpng", "-o", File.join(dir, "package-classes.png"), File.join(dir, "classes.dot"))
      system(@conf.dot_exe, "-Tcmapx", "-o", File.join(dir, "package-classes.cmapx"), File.join(dir, "classes.dot"))
      #File.delete(File.join(dir, "types.dot"))
    end

    asinterfaces = @package.interfaces
    unless asinterfaces.empty?
      write_file(dir, "interfaces.dot") do |io|
	io.puts("strict digraph interface_diagram {")
	  io.puts("  rankdir=LR;")
	  asinterfaces.each do |astype|
	    io.puts("  #{astype.unqualified_name}[")
	    io.puts("    label=\"#{astype.unqualified_name}\",")
	    io.puts("    URL=\"#{astype.unqualified_name}.html\",")
	    io.puts("    tooltip=\"#{astype.qualified_name}\",")
	    io.puts("    fontname=\"Times-Italic\",") if astype.is_a?(ASInterface)
	    io.puts("    shape=\"record\"")
	    io.puts("  ];")
	  end
	  asinterfaces.each do |astype|
	    parent = astype.extends
	    if !parent.nil? && parent.resolved?
	      if parent.resolved_type.package_name == @package.name
		io.puts("  #{parent.resolved_type.unqualified_name} -> #{astype.unqualified_name};")
	      end
	    end
	  end
	io.puts("}")
      end
      system(@conf.dot_exe, "-Tpng", "-o", File.join(dir, "package-interfaces.png"), File.join(dir, "interfaces.dot"))
      system(@conf.dot_exe, "-Tcmapx", "-o", File.join(dir, "package-interfaces.cmapx"), File.join(dir, "interfaces.dot"))
      #File.delete(File.join(dir, "types.dot"))
    end
  end

  class XMLAdapter
    def initialize(out)
      @out = out
    end

    def tag_start(name, attrs)
      attr_map = {}
      attrs.each do |el|
	attr_map[el[0]] = el[1]
      end
      @out.start_tag(name, attr_map)
    end

    def tag_end(name)
      @out.end_tag(name)
    end

    def text(text)
      @out.pcdata(text)
    end
  end

  def copy_xml(io, out)
    listener = XMLAdapter.new(out)
    REXML::Document.parse_stream(io, listener)
  end

end


class PackageFramePage < Page

  def initialize(package)
    dir = package_dir_for(package)
    super("package-frame", dir)
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
  def initialize(type_agregator)
    super("overview-summary")
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

  def initialize(type_agregator)
    super("overview-frame")
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
  write_file(path_name, "package-list") do |out|
    type_agregator.each_package do |package|
      out.puts(package.name) unless package.name == ""
    end
  end
end


class AllTypesFramePage < Page

  def initialize(type_agregator)
    super("all-types-frame")
    @type_agregator = type_agregator
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

  def initialize
    super("frameset")
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
    out.link_type(@astype)
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
    out.link_method(@asmember)
    out.pcdata(" method in ")
    out.link_type(@astype, true)
  end
end

class FieldIndexTerm < MemberIndexTerm
  def link(out)
    href_prefix = out.link_for_type(@astype)
    out.html_a("href"=>"#{href_prefix}#field_#{@asmember.name}") do
      out.pcdata(@asmember.name)
    end
    out.pcdata(" field in ")
    out.link_type(@astype, true)
  end
end

class IndexPage < BasicPage
  def initialize(type_agregator)
    super("index", "index-files")
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

def make_page_list(conf, type_agregator)
  list = []

  list << FramesetPage.new()
  list << OverviewPage.new(type_agregator)
  list << OverviewFramePage.new(type_agregator)
  list << AllTypesFramePage.new(type_agregator)

  # packages..
  type_agregator.each_package do |package|
    list << PackageIndexPage.new(conf, package)
    list << PackageFramePage.new(package)
  end

  # types..
  type_agregator.each_type do |type|
    if type.document?
      list << TypePage.new(type)
    end
  end

  list << IndexPage.new(type_agregator)

  list
end

def create_all_pages(conf, list)
  conf.progress_listener.generating_pages(list.length) do
    list.each_with_index do |page, index|
      page.title_extra = conf.title
      page.encoding = conf.input_encoding
      conf.progress_listener.generate_page(index, page)
      create_page(conf.output_dir, page)
    end
  end
end

def document_types(conf, type_agregator)
  list = make_page_list(conf, type_agregator)
  create_all_pages(conf, list)
  package_list(conf.output_dir, type_agregator)
  stylesheet(conf.output_dir)
end

# vim:softtabstop=2:shiftwidth=2

