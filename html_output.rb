
require 'xmlwriter'
require 'xhtmlwriter'
require 'doc_comment'

def link_type_proxy(out, type_proxy, qualified=false)
  if type_proxy.resolved? && type_proxy.resolved_type.document?
    link_type(out, type_proxy.resolved_type, qualified)
  else
    if type_proxy.resolved?
      if type_proxy.resolved_type.instance_of?(ASInterface)
        out.element_span(type_proxy.local_name, {"class"=>"interface_name"})
      else
        out.element_span(type_proxy.local_name, {"class"=>"class_name"})
      end
    else
      out.element_span(type_proxy.local_name, {"class"=>"unresolved_type_name"})
    end
  end
end

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
    out.element_a(type.qualified_name, {"href"=>href,
                                        "class"=>attr_class,
                                        "title"=>attr_title})
  else
    out.element_a(type.unqualified_name, {"href"=>href,
                                          "class"=>attr_class,
                                          "title"=>attr_title})
  end
end

def method_synopsis(out, method)
  out.element_code("class"=>"method_synopsis") do
    if method.access.is_static
      out.pcdata("static ")
    end
    unless method.access.visibility.nil?
      out.pcdata("#{method.access.visibility.body} ")
    end
    out.pcdata("function ")
    out.element_strong("class"=>"method_name") do
      out.pcdata(method.name)
    end
    out.pcdata("(")
    method.arguments.each_with_index do |arg, index|
      out.pcdata(", ") if index > 0
      out.pcdata(arg.name)
      if arg.arg_type
        out.pcdata(":")
	link_type_proxy(out, arg.arg_type)
      end
    end
    out.pcdata(")")
    if method.return_type
      out.pcdata(":")
      link_type_proxy(out, method.return_type)
    end
  end
end

def field_synopsis(out, field)
  out.element_code("class"=>"field_synopsis") do
    if field.instance_of?(ASImplicitField)
      implicit_field_synopsis(out, field)
    else
      explicit_field_synopsis(out, field)
    end
  end
end

def explicit_field_synopsis(out, field)
  if field.access.is_static
    out.pcdata("static ")
  end
  unless field.access.visibility.nil?
    out.pcdata("#{field.access.visibility.body} ")
  end
  out.element_strong("class"=>"field_name") do
    out.pcdata(field.name)
  end
  if field.field_type
    out.pcdata(":")
    link_type_proxy(out, field.field_type)
  end
end

def implicit_field_synopsis(out, field)
  if field.access.is_static
    out.pcdata("static ")
  end
  unless field.access.visibility.nil?
    out.pcdata("#{field.access.visibility.body} ")
  end
  out.element_strong("class"=>"field_name") do
    out.pcdata(field.name)
  end
  field_type = field.field_type
  unless field_type.nil?
    out.pcdata(":")
    link_type_proxy(out, field_type)
  end
  unless field.readwrite?
    out.pcdata(" ")
    out.element_em("class"=>"read_write_only") do
      if field.read?
	out.pcdata("[Read Only]")
      else
	out.pcdata("[Write Only]")
      end
    end
  end
end


def class_navigation(out)
  out.element_div("class"=>"main_nav") do
    out.element_a("Overview", {"href"=>base_path("overview-summary.html")})
    out.element_a("Package", {"href"=>"package-summary.html"})
    out.element_span("Class", {"class"=>"nav_current"})
    out.element_a("Index", {"href"=>base_path("index-files/index.html")})
  end
end

def comment_has_blocktype?(comment_data, type)
  comment_data.each_block do |block|
    return true if block.is_a?(type)
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

def comment_each_exception(comment_data)
  comment_data.each_block do |block|
    yield block if block.is_a?(ThrowsBlockTag)
  end
end

def comment_each_seealso(comment_data)
  comment_data.each_block do |block|
    yield block if block.is_a?(SeeBlockTag)
  end
end

def comment_find_param(comment_data, param_name)
  comment_data.each_block do |block|
    if block.is_a?(ParamBlockTag) && block.param_name == param_name
      return block;
    end
  end
  return nil
end

def comment_find_return(comment_data)
  comment_data.each_block do |block|
    return block if block.is_a?(ReturnBlockTag)
  end
  return nil
end

def document_method(out, type, method, alt_row=false)
  css_class = "method_details"
  css_class << " alt_row" if alt_row
  out.element_div("class"=>css_class) do
    out.element_a("name"=>"method_#{method.name}")
    out.element_h3(method.name)
    method_synopsis(out, method)
    if method.comment
      out.element_blockquote do
        comment_data = method.comment
        output_doccomment_blocktag(out, comment_data[0])
        out.element_dl("class"=>"method_additional_info") do
	  # TODO: assumes that params named in docs match formal arguments
	  #       should really filter out those that don't match before this
	  #       test
	  if comment_has_params?(comment_data)
	    out.element_dt("Parameters")
	    out.element_dd do
	      out.element_table("class"=>"arguments", "summary"=>"") do
		method.arguments.each do |arg|
		  desc = comment_find_param(comment_data, arg.name)
		  if desc
		    out.element_tr do
		      out.element_td do
			out.element_code(arg.name)
		      end
		      out.element_td do
                        output_doccomment_blocktag(out, desc)
		      end
		    end
		  end
		end
	      end
	    end
	  end
	  return_comment = comment_find_return(comment_data)
	  unless return_comment.nil?
	    out.element_dt("Return")
	    out.element_dd do
              output_doccomment_blocktag(out, return_comment)
	    end
	  end
	  if comment_has_exceptions?(comment_data)
            out.element_dt("throws")
            out.element_dd do
	      out.element_table("class"=>"exceptions", "summary"=>"") do
	        comment_each_exception(comment_data) do |exception_comment|
		  out.element_tr do
		    out.element_td do
		      link_type_proxy(out, exception_comment.exception_type)
		    end
		    out.element_td do
                      output_doccomment_blocktag(out, exception_comment)
		    end
		  end
	        end
	      end
	    end
	  end
	  if comment_has_seealso?(comment_data)
	    out.element_dt("See Also")
	    out.element_dd do
	      comment_each_seealso(comment_data) do |see_comment|
	        out.element_p do
                  output_doccomment_blocktag(out, see_comment)
		end
	      end
	    end
	  end
	end
      end
    end
  end
end

def output_doccomment_blocktag(out, block)
  block.each_inline do |inline|
    output_doccomment_inlinetag(out, inline)
  end
end

def output_doccomment_inlinetag(out, inline)
  if inline.is_a?(String)
    out.pcdata(inline)
  elsif inline.is_a?(LinkTag)
    link_type_proxy(out, inline.target)
  else
    out.element_em(inline.inspect)
  end
end

def document_field(out, type, field)
  out.element_a("name"=>"field_#{field.name}")
  out.element_h3(field.name)
  out.element_div("class"=>"field_details") do
    field_synopsis(out, field)
    if field.comment
      out.element_blockquote do
	comment_data = field.comment
	output_doccomment_blocktag(out, comment_data[0])
        out.element_dl("class"=>"field_additional_info") do
	  if comment_has_seealso?(comment_data)
	    out.element_dt("See Also")
	    out.element_dd do
	      comment_each_seealso(comment_data) do |see_comment|
	        out.element_p do
                  output_doccomment_blocktag(out, see_comment)
		end
	      end
	    end
	  end
	end
      end
    end
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

def html_file(name, title, encoding=nil)
  write_file("#{name}.html") do |io|
    out = XHTMLWriter.new(XMLWriter.new(io))
    encoding = "iso-8859-1" if encoding.nil?
    out.pi("xml version=\"1.0\" encoding=\"#{encoding}\"")
    out.element_html do
      out.element_head do
        out.element_title(title)
        out.element_link("rel"=>"stylesheet",
	                 "type"=>"text/css",
	                 "href"=>base_path("style.css"))
        out.element_meta("name"=>"generator", "content"=>"http://www.badgers-in-foil.co.uk/projects/as2api/")
      end
      yield out
    end
  end
end

def html_body(name, title, encoding=nil)
  html_file(name, title, encoding) do |out|
    out.element_body do
      yield out
      footer(out)
    end
  end
end

def footer(out)
  out.element_div("class"=>"footer") do
    out.element_a("as2api", {"href"=>"http://www.badgers-in-foil.co.uk/projects/as2api/", "title"=>"ActionScript 2 API Documentation Generator"})
  end
end

def type_hierachy(out, type)
  # TODO: ASCII art is an accessability problem.  Replace with images that have
  #       alt-text, or use CSS to generate content, e.g.
  #          <span class="inherit_relation" title="inherited by"></span>
  out.element_pre("class"=>"type_hierachy") do
    count = 0
    unless type.extends.nil?
      count = type_hierachy_recursive(out, type.extends)
    end
    if count > 0
      out.pcdata("   " * count)
      out.pcdata("+--")
    end
    out.element_strong(type.qualified_name)
  end
end

def type_hierachy_recursive(out, type_proxy)
  count = 0
  if type_proxy.resolved?
    type = type_proxy.resolved_type
    unless type.extends.nil?
      count = type_hierachy_recursive(out, type.extends)
    end
  else
    out.pcdata("????\n")
    count = 1
  end
  if count > 0
    out.pcdata("   " * count)
    out.pcdata("+--")
  end
  link_type_proxy(out, type_proxy, true)
  out.pcdata("\n")
  return count + 1
end

def field_index_list(out, type)
  out.element_div("class"=>"field_index") do
    out.element_h2("Field Index")
    list_fields(out, type)
    out.element_dl do
      type.each_ancestor do |type|
	if type.fields?
	  out.element_dt do
	    out.pcdata("Inherited from ")
	    link_type(out, type)
	  end
	  out.element_dd do
	    list_fields(out, type, link_for_type(type))
	  end
	end
      end
    end
  end
end

def document_member?(member)
  !member.access.private?
end

def list_fields(out, type, href_prefix="")
  fields = type.fields.sort
  index = 0
  fields.each do |field|
    next unless document_member?(field)
    out.pcdata(", ") if index > 0
    out.element_code do
      out.element_a("href"=>"#{href_prefix}#field_#{field.name}") do
	out.pcdata(field.name)
      end
    end
    index += 1
  end
end

def field_detail_list(out, type)
  out.element_div("class"=>"field_detail_list") do
    out.element_h2("Field Detail")
    type.each_field do |field|
      document_field(out, type, field) if document_member?(field)
    end
  end
end


def method_index_list(out, type)
  out.element_div("class"=>"method_index") do
    out.element_h2("Method Index")
    if type.constructor? && document_member?(type.constructor)
      out.element_p do
        out.element_code do
          out.pcdata("new ")
	    out.element_a("href"=>"#method_#{type.constructor.name}") do
	      out.pcdata(type.constructor.name+"()")
	    end
        end
      end
    end
    known_method_names = []
    list_methods(out, type, known_method_names)
    out.element_dl do
      type.each_ancestor do |type|
	if type.methods?
	  out.element_dt do
	    out.pcdata("Inherited from ")
	    link_type(out, type)
	  end
	  out.element_dd do
	    list_methods(out, type, known_method_names, link_for_type(type))
	  end
	end
      end
    end
  end
end

def list_methods(out, type, known_method_names, href_prefix="")
  methods = type.methods.select do |method|
    !known_method_names.include?(method.name) && document_member?(method)
  end
  methods.sort!
  methods.each_with_index do |method, index|
    known_method_names << method.name
    out.pcdata(", ") if index > 0
    out.element_a("href"=>"#{href_prefix}#method_#{method.name}") do
      out.pcdata(method.name+"()")
    end
  end
end

def method_detail_list(out, type)
  out.element_div("class"=>"method_detail_list") do
    out.element_h2("Method Detail")
    count = 0
    type.each_method do |method|
      next unless document_member?(method)
      document_method(out, type, method, count%2==0)
      count += 1
    end
  end
end

def constructor_detail(out, type)
  out.element_div("class"=>"constructor_detail_list") do
    out.element_h2("Constructor Detail")
    document_method(out, type, type.constructor)
  end
end

def document_type(type)
  encoding = if type.source_utf8
    "utf-8"
  else
    "iso-8859-1"
  end
  html_body(type.unqualified_name, type.qualified_name, encoding) do |out|
    out.element_a("", {"href"=>"#skip_nav", "title"=>"Skip navigation"})  # accessability
    class_navigation(out)
    out.element_a("", {"name"=>"skip_nav"})
    if type.instance_of?(ASClass)
      out.element_h1("Class "+type.qualified_name)
    elsif type.instance_of?(ASInterface)
      out.element_h1("Interface "+type.qualified_name)
    end

    type_hierachy(out, type)

    if type.implements_interfaces?
      out.element_div("class"=>"interfaces") do
	out.element_h2("Implemented Interfaces")
	type.each_interface do |interface|
	  # TODO: need to resolve interface name, make links
	  out.element_code do
	    link_type_proxy(out, interface)
	  end
	  out.pcdata(" ")
	end
      end
    end
    out.element_div("class"=>"type_description") do
      if type.comment
        comment_data = type.comment

	out.element_h2("Description")
	out.element_p do
          output_doccomment_blocktag(out, comment_data[0])
	end
	out.element_dl("class"=>"type_details") do
	  if comment_has_seealso?(comment_data)
	    out.element_dt("See Also")
	    out.element_dd do
	      comment_each_seealso(comment_data) do |see_comment|
	        out.element_p do
                  output_doccomment_blocktag(out, see_comment)
		end
	      end
	    end
	  end
	end
      end
    end
    
    field_index_list(out, type) if type.fields?
    method_index_list(out, type) if type.methods?
    constructor_detail(out, type) if type.constructor? && document_member?(type.constructor)
    field_detail_list(out, type) if type.fields?
    method_detail_list(out, type) if type.methods?

    class_navigation(out)
  end
end

def list_see_also(out, docs)
  docs.each_see_also do |see|
    out.comment(" parsing for see-also not done yet ")
    out.element_p(see)
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

def package_navigation(out)
  out.element_div("class"=>"main_nav") do
    out.element_a("Overview", {"href"=>base_path("overview-summary.html")})
    out.element_span("Package", {"class"=>"nav_current"})
    out.element_span("Class")
    out.element_a("Index", {"href"=>base_path("index-files/index.html")})
  end
end

def package_pages(package)
  in_subdir(package_dir_for(package)) do
    package_index(package)
    package_frame(package)
  end
end

def package_index(package)
  html_body("package-summary", "Package #{package_display_name_for(package)} API Documentation") do |out|
    out.element_a("", {"href"=>"#skip_nav", "title"=>"Skip navigation"})  # accessability
    package_navigation(out)
    out.element_a("", {"name"=>"skip_nav"})
    out.element_h1("Package "+package_display_name_for(package))
    interfaces = package.interfaces
    unless interfaces.empty?
      interfaces.sort!
      out.element_table("class"=>"summary_list", "summary"=>"") do
	out.element_tr do
	  out.element_th("Interface Summary")
	end
	interfaces.each do |type|
	  out.element_tr do
      
	    out.element_td do
	      out.element_a(type.unqualified_name, {"href"=>type.unqualified_name+".html"})
	    end
	    #out.element_td do
	      # TODO: package description
	    #end
	  end
	end
      end
    end
    classes = package.classes
    unless classes.empty?
      classes.sort!
      out.element_table("class"=>"summary_list", "summary"=>"") do
	out.element_tr do
	  out.element_th("Class Summary")
	end
	classes.each do |type|
	  out.element_tr do
      
	    out.element_td do
	      out.element_a(type.unqualified_name, {"href"=>type.unqualified_name+".html"})
	    end
	    #out.element_td do
	      # TODO: package description
	    #end
	  end
	end
      end
    end
    package_navigation(out)
  end
end

def package_frame(package)
  html_file("package-frame", "Package #{package_display_name_for(package)} API Naviation") do |out|
    out.element_body do
      # TODO: don't use <strong>
      out.element_strong do
	out.element_a(package_display_name_for(package), {"href"=>"package-summary.html", "target"=>"type_frame"})
      end
      interfaces = package.interfaces
      unless interfaces.empty?
	interfaces.sort!
	out.element_table("class"=>"navigation_list") do
	  out.element_tr do
	    out.element_th("Interfaces")
	  end
	  interfaces.each do |type|
	    out.element_tr do
	
	      out.element_td do
		out.element_a(type.unqualified_name, {"href"=>type.unqualified_name+".html", "target"=>"type_frame", "title"=>type.qualified_name})
	      end
	    end
	  end
	end
      end
      classes = package.classes
      unless classes.empty?
	classes.sort!
	out.element_table("class"=>"navigation_list") do
	  out.element_tr do
	    out.element_th("Classes")
	  end
	  classes.each do |type|
	    out.element_tr do
	
	      out.element_td do
		out.element_a(type.unqualified_name, {"href"=>type.unqualified_name+".html", "target"=>"type_frame", "title"=>type.qualified_name})
	      end
	    end
	  end
	end
      end
    end
  end
end

def overview_navigation(out)
  out.element_div("class"=>"main_nav") do
    out.element_span("Overview", {"class"=>"nav_current"})
    out.element_span("Package")
    out.element_span("Class")
    out.element_a("Index", {"href"=>"index-files/index.html"})
  end
end

def overview(type_agregator)
  html_body("overview-summary", "API Overview") do |out|
    out.element_a("", {"href"=>"#skip_nav", "title"=>"Skip navigation"})  # accessability
    overview_navigation(out)
    out.element_a("", {"name"=>"skip_nav"})
    out.element_h1("API Overview")
    out.element_table("class"=>"summary_list", "summary"=>"") do
      out.element_tr do
	out.element_th("Packages", {"colspan"=>"2"})
      end
      packages = type_agregator.packages.sort
      packages.each do |package|
	out.element_tr do
    
	  out.element_td do
	    name = package_display_name_for(package)
	    out.element_a(name, {"href"=>package_link_for(package, "package-summary.html")})
	  end
	  out.element_td do
	    # TODO: package description
	  end
	end
      end
    end
    overview_navigation(out)
  end
end

def overview_frame(type_agregator)
  html_file("overview-frame", "API Overview") do |out|
    out.element_body do
      out.element_table("class"=>"navigation_list") do
	out.element_tr do
	  out.element_th("Packages")
	end
	  out.element_tr do
      
	    out.element_td do
	      out.element_a("(All Types)", {"href"=>"all-types-frame.html", "target"=>"current_package_frame"})
	    end
	  end
	packages = type_agregator.packages.sort
	packages.each do |package|
	  out.element_tr do
      
	    out.element_td do
	      name = package_display_name_for(package)
	      
	      out.element_a(name, {"href"=>package_link_for(package, "package-frame.html"), "target"=>"current_package_frame", "title"=>name})
	    end
	  end
	end
      end
    end
  end
end

def package_list(type_agregator)
  # REVISIT: Will a package list actually be useful for ActionScript, or can
  #          we always assume that any code that makes reference to a type
  #          must have access to that type's source in order to compile?
  #          (In theory, this file will allow javadoc to link to ActionScript
  #          classes, so maybe keep it just for that.)
  write_file("package-list") do |out|
    type_agregator.each_package do |package|
      out.puts(package.name) unless package.name == ""
    end
  end
end

def all_types_frame(type_agregator)
  html_file("all-types-frame", "as2api") do |out|
    out.element_body do
      out.element_table("class"=>"navigation_list") do
        out.element_tr do
	  out.element_th("All Types")
	end
	types = type_agregator.types.sort do |a,b|
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
            out.element_tr do
              out.element_td do
	        out.element_a(type.unqualified_name, {"href"=>href, "title"=>type.qualified_name, "target"=>"type_frame"})
	      end
	    end
	  end
	end
      end
    end
  end
end

def frameset
  html_file("frameset", "as2api") do |out|
    out.element_frameset("cols"=>"20%,80%") do
      out.element_frameset("rows"=>"30%,70%") do
	out.element_frame("src"=>"overview-frame.html",
	                  "name"=>"all_packages_frame",
	                  "title"=>"All Packages")
	out.element_frame("src"=>"all-types-frame.html",
	                  "name"=>"current_package_frame",
                          "title"=>"All types")
      end
      out.element_frame("src"=>"overview-summary.html",
                        "name"=>"type_frame",
                        "title"=>"Package and type descriptions")
    end
    out.element_noframes do
      out.element_a("Non-frameset overview page", {"href"=>"overview-summary.html"})
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
    out.pcdata(@astype.package_name)
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
    href_prefix = link_for_type(@astype)
    out.element_a("href"=>"#{href_prefix}#method_#{@asmember.name}") do
      out.pcdata(@asmember.name + "()")
    end
    out.pcdata(" method in ")
    link_type(out, @astype, true)
  end
end

class FieldIndexTerm < MemberIndexTerm
  def link(out)
    href_prefix = link_for_type(@astype)
    out.element_a("href"=>"#{href_prefix}#field_#{@asmember.name}") do
      out.pcdata(@asmember.name)
    end
    out.pcdata(" field in ")
    link_type(out, @astype, true)
  end
end

def index_navigation(out)
  out.element_div("class"=>"main_nav") do
    out.element_a("Overview", {"href"=>base_path("overview-summary.html")})
    out.element_span("Package")
    out.element_span("Class")
    out.element_span("Index", {"class"=>"nav_current"})
  end
end

def index_files(type_agregator)
  index = []
  # TODO: include packages
  type_agregator.each_type do |astype|
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

  in_subdir("index-files") do
    html_file("index", "Alphabetical Index") do |out|
      index_navigation(out)
      index.each do |element|
	out.element_p do
	  element.link(out)
	end
      end
      index_navigation(out)
    end
  end
end

def document_types(output_path, type_agregator)
  in_subdir(output_path) do
    frameset()
    overview(type_agregator)
    overview_frame(type_agregator)
    package_list(type_agregator)
    all_types_frame(type_agregator)

    # packages..
    type_agregator.each_package do |package|
      package_pages(package)
    end

    # types..
    type_agregator.each_type do |type|
      if type.document?
	in_subdir(type.package_name.gsub(/\./, "/")) do
	  document_type(type)
	end
      end
    end

    index_files(type_agregator)
  end
end

# vim:softtabstop=2:shiftwidth=2
