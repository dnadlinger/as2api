
require 'xmlwriter'

def link_type(out, type, qualified=false)
  if type.resolved?
    href = base_path(type.resolved_type.qualified_name.gsub(/\./, "/")+".html")
    if qualified
      out.simple_element("a", type.resolved_type.qualified_name, {"href"=>href})
    else
      out.simple_element("a", type.local_name, {"href"=>href,
                                                "title"=>type.resolved_type.qualified_name})
    end
  else
    out.simple_element("span", type.local_name, {"class"=>"unresolved_type"})
  end
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
    method.arguments.each_with_index do |arg, index|
      out.pcdata(", ") if index > 0
      out.pcdata(arg.name)
      if arg.arg_type
        out.pcdata(":")
	link_type(out, arg.arg_type)
      end
    end
    out.pcdata(")")
    if method.return_type
      out.pcdata(":")
      link_type(out, method.return_type)
    end
  end
end

def field_synopsis(out, field)
  out.element("code", {"class", "field_synopsis"}) do
    if field.access.is_static
      out.pcdata("static ")
    end
    unless field.access.visibility.nil?
      out.pcdata("#{field.access.visibility.body} ")
    end
    out.element("strong", {"class"=>"method_name"}) do
      out.pcdata(field.name)
    end
    if field.field_type
      out.pcdata(":")
      link_type(out, field.field_type)
    end
  end
end

def class_navigation(out)
  out.element("div", {"class", "main_nav"}) do
    out.simple_element("a", "Overview", {"href"=>base_path("overview-summary.html")})
    out.simple_element("a", "Package", {"href"=>"package-summary.html"})
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
        out.element("dl", {"class"=>"method_additional_info"}) do
	  # TODO: assumes that params named in docs match formal arguments
	  #       should really filter out those that don't match before this
	  #       test
	  if docs.parameters?
	    out.simple_element("dt", "Parameters")
	    out.element("dd") do
	      out.element("table", {"class"=>"arguments"}) do
		method.arguments.each do |arg|
		  desc = docs.param(arg.name)
		  if desc
		    out.element("tr") do
		      out.element("td") do
			out.simple_element("code", arg.name)
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
	  # TODO: see-also
	end
      end
    end
  end
end

def document_field(out, field)
  out.empty_tag("a", {"name"=>"field_#{field.name}"})
  out.simple_element("h3", field.name)
  out.element("div", {"class"=>"field_details"}) do
    field_synopsis(out, field)
    if field.comment
      out.element("blockquote") do
	docs = DocComment.new
	docs.parse(field.comment.body)
        out.pcdata(docs.description)
        out.element("dl", {"class"=>"field_additional_info"}) do
	  # TODO: see-also
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
    out = XMLWriter.new(io)
    encoding = "iso-8859-1" if encoding.nil?
    out.pi("xml version=\"1.0\" encoding=\"#{encoding}\"")
    out.element("html") do
      out.element("head") do
        out.simple_element("title", title)
        out.empty_tag("link", {"rel"=>"stylesheet",
	                       "type"=>"text/css",
			       "href"=>base_path("style.css")})
      end
      out.element("body") do
        yield out
	footer(out)
      end
    end
  end
end

def footer(out)
  out.element("div", {"class"=>"footer"}) do
    out.simple_element("a", "as2api", {"href"=>"http://www.badgers-in-foil.co.uk/projects/as2api/", "title"=>"ActionScript 2 API Documentation Generator"})
  end
end

def type_hierachy(out, type)
  out.element("pre", {"class"=>"type_hierachy"}) do
    count = 0
    unless type.extends.nil?
      count = type_hierachy_recursive(out, type.extends)
    end
    if count > 0
      out.pcdata("   " * count)
      out.pcdata("+--")
    end
    out.simple_element("strong", type.qualified_name)
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
  link_type(out, type_proxy, true)
  out.pcdata("\n")
  return count + 1
end

def field_index_list(out, type)
  out.element("div", {"class"=>"field_index"}) do
    out.simple_element("h2", "Field Index")
    type.each_field do |field|
      out.element("a", {"href"=>"#field_#{field.name}"}) do
	out.pcdata(field.name)
      end
      out.pcdata(" ")
    end
  end
end

def field_detail_list(out, type)
  out.element("div", {"class"=>"field_detail_list"}) do
    out.simple_element("h2", "Field Detail")
    type.each_field do |field|
      document_field(out, field)
    end
  end
end


def method_index_list(out, type)
  out.element("div", {"class"=>"method_index"}) do
    out.simple_element("h2", "Method Index")
    type.each_method do |method|
      out.element("a", {"href"=>"#method_#{method.name}"}) do
	out.pcdata(method.name+"()")
      end
      out.pcdata(" ")
    end
  end
end

def method_detail_list(out, type)
  out.element("div", {"class"=>"method_detail_list"}) do
    out.simple_element("h2", "Method Detail")
    type.each_method do |method|
      document_method(out, method)
    end
  end
end

def document_type(type)
  encoding = if type.source_utf8
    "utf-8"
  else
    "iso-8859-1"
  end
  html_file(type.unqualified_name, type.qualified_name, encoding) do |out|
    out.element("body") do
      class_navigation(out)
      if type.instance_of?(ASClass)
	out.simple_element("h1", "Class "+type.qualified_name)
      elsif type.instance_of?(ASInterface)
	out.simple_element("h1", "Interface "+type.qualified_name)
      end

      type_hierachy(out, type)

      if type.implements_interfaces?
        out.element("div", {"class"=>"interfaces"}) do
          out.simple_element("h2", "Implemented Interfaces")
          type.each_interface do |interface|
            # TODO: need to resolve interface name, make links
            out.element("code") do
	      link_type(out, interface)
	    end
            out.pcdata(" ")
          end
        end
      end
      out.element("div", {"class"=>"type_description"}) do
        if type.comment
	  docs = DocComment.new
	  docs.parse(type.comment.body)

          out.simple_element("h2", "Description")
          out.element("p") do
            out.pcdata(docs.description)
          end
          out.element("dl", {"class"=>"type_details"}) do
	    if docs.seealso?
              out.simple_element("dt", "See Also")
              out.element("dd") do
	        docs.each_see_also do |see|
		  out.comment(" parsing for see-also not done yet ")
		  out.simple_element("p", see)
		end
              end
	    end
	  end
        end
      end
      
      field_index_list(out, type) if type.fields?
      method_index_list(out, type) if type.methods?
      field_detail_list(out, type) if type.fields?
      method_detail_list(out, type) if type.methods?

      class_navigation(out)
    end
  end
end

def package_dir_for(package)
  package.name.gsub(/\./, "/")
end

def package_display_name_for(package)
  return "(Default)" if package.name == ""
  package.name
end

def package_summary_for(package)
  return "package-summary.html" if package.name == ""
  package_dir_for(package) + "/package-summary.html"
end

def package_navigation(out)
  out.element("div", {"class", "main_nav"}) do
    out.simple_element("a", "Overview", {"href"=>base_path("overview-summary.html")})
    out.simple_element("span", "Package", {"class"=>"nav_current"})
    out.simple_element("span", "Class")
  end
end

def package_index(package)
  in_subdir(package_dir_for(package)) do
    html_file("package-summary", "Package #{package_display_name_for(package)} API Documentation") do |out|
      package_navigation(out)
      out.simple_element("h1", "Package "+package_display_name_for(package))
      out.element("table", {"class"=>"summary_list"}) do
	out.element("tr") do
	  out.simple_element("th", "Type Summary", {"colspan"=>"2"})
	end
	package.each_type do |type|
	  out.element("tr") do
      
	    out.element("td") do
	      out.simple_element("a", type.unqualified_name, {"href"=>type.unqualified_name+".html"})
	    end
	    out.element("td") do
	      # TODO: package description
	    end
	  end
	end
      end
      package_navigation(out)
    end
  end
end

def overview_navigation(out)
  out.element("div", {"class", "main_nav"}) do
    out.simple_element("span", "Overview", {"class"=>"nav_current"})
    out.simple_element("span", "Package")
    out.simple_element("span", "Class")
  end
end

def overview(type_agregator)
  html_file("overview-summary", "API Overview") do |out|
    overview_navigation(out)
    out.simple_element("h1", "API Overview")
    out.element("table", {"class"=>"summary_list"}) do
      out.element("tr") do
	out.simple_element("th", "Packages", {"colspan"=>"2"})
      end
      type_agregator.each_package do |package|
	out.element("tr") do
    
	  out.element("td") do
	    name = package_display_name_for(package)
	    out.simple_element("a", name, {"href"=>package_summary_for(package)})
	  end
	  out.element("td") do
	    # TODO: package description
	  end
	end
      end
    end
    overview_navigation(out)
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

def document_types(output_path, type_agregator)
  in_subdir(output_path) do
    overview(type_agregator)
    package_list(type_agregator)

    # packages..
    type_agregator.each_package do |package|
      package_index(package)
    end

    # types..
    type_agregator.each_type do |type|
      in_subdir(type.package_name.gsub(/\./, "/")) do
	document_type(type)
      end
    end
  end
end
