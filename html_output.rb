
require 'xmlwriter'

def link_type(out, type, qualified=false)
  if type.resolved?
    href = base_path(type.resolved_type.name_s+".html")
    if qualified
      out.simple_element("a", type.resolved_type.name_s, {"href"=>href})
    else
      out.simple_element("a", type.local_name, {"href"=>href,
                                                "title"=>type.resolved_type.name_s})
    end
  else
    out.simple_element("em", type.local_name, {"class"=>"unresolved_type"})
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

def class_navigation(out)
  out.element("div", {"class", "main_nav"}) do
    out.simple_element("a", "Overview", {"href"=>"index.html"})
    out.simple_element("span", "Package")
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
        out.element("dl", {"class"=>"method_detail_list"}) do
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
	end
      end
    end
  end
end

$base_path = ""
$path = "."

def base_path(file)
  "#{$base_path}#{file}"
end

def in_subdir(*path)
  save_path = $path
  save_base_path = $base_path
  path.each do |part|
    $base_path << ".." << File::SEPARATOR if $path!="."
    $path = File.join($path, part)
    unless FileTest.exist?($path)
      Dir.mkdir($path)
    end
  end
puts $base_path
  yield
  $path = save_path
  $base_path = save_base_path
end

def html_file(name, title, encoding=nil)
  File.open(File.join($path, "#{name}.html"), "w") do |io|
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
      end
    end
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
    out.simple_element("strong", type.name.join("."))
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

def document_type(type)
  encoding = if type.source_utf8
    "utf-8"
  else
    "iso-8859-1"
  end
  html_file(type.name.join("."), type.name.join("."), encoding) do |out|
    out.element("body") do
      class_navigation(out)
      out.simple_element("h1", type.name.join("."))

      type_hierachy(out, type)

      if type.implements_interfaces?
        out.element("div", {"class"=>"interfaces"}) do
          out.simple_element("h2", "Implemented Interfaces")
          type.each_interface do |interface|
            # TODO: need to resolve interface name, make links
            out.simple_element("code", interface.join('.'))
            out.pcdata(" ")
          end
          out.comment(" no more interfaces ")
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
          out.element("dl", {"class"=>"method_detail_list"}) do
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
      if type.methods?
	out.element("div", {"class"=>"method_index"}) do
	  out.simple_element("h2", "Method Index")
	  type.each_method do |method|
	    out.element("a", {"href"=>"#method_#{method.name}"}) do
	      out.pcdata(method.name+"()")
	    end
	    out.pcdata(" ")
	  end
	end

	out.element("div", {"class"=>"method_detail_list"}) do
	  out.simple_element("h2", "Method Detail")
	  type.each_method do |method|
	    document_method(out, method)
	  end
	end
      end
      class_navigation(out)
    end
  end
end

def document_types(types)
  in_subdir("apidoc") do
    html_file("index", "API Documentation") do |out|
      types.each do |type|
        document_type(type)
        out.element("p") do
	  out.element("a", {"href"=>"#{type.name.join('.')}.html"}) do
	    out.pcdata(type.name.join('.'))
	  end
	end
      end
    end
  end
end
