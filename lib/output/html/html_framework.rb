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

require 'output/utils'

require 'xmlwriter'
require 'xhtmlwriter'
require 'output/xml/xml_formatter'


GetText.bindtextdomain("as2api")

PROJECT_PAGE = "http://www.badgers-in-foil.co.uk/projects/as2api/"


NavLink = Struct.new("NavLink", :href, :content, :title, :is_current)

# superclass for a kind of object able to build a navigation link for
# BasicPage instances.
class NavLinkBuilder
  def initialize(conf, content)
    @conf, @content = conf, content
  end

  def build_for_page(page)
    NavLink.new(href_on(page), GetText.gettext(@content), title_on(page), is_current?(page))
  end

  def _(msg)
    GetText.gettext(msg)
  end
end


class Page
  include XHTMLWriter

  # forwards method call to GetText.  Defined here so that subclasses can use
  # gettext-like _("foo") calls, but don't have to have every individual file
  # call bindtextdomain
  def _(msg)
    GetText.gettext(msg)
  end

  def initialize(base_name, path_name=nil)
    @path_name = path_name
    @base_name = base_name
    @encoding = nil
    @doctype_id = :strict
    @title = nil
    @title_extra = nil
    @type = nil
    @io = nil  # to be set during the lifetime of generate() call
  end

  attr_accessor :path_name, :encoding, :lang, :doctype_id, :title_extra

  attr_writer :title, :base_name

  def base_name
    "#{@base_name}.html"
  end

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

  def lang_to_gettext_locale(str)
    return nil unless str
    str.gsub(/-/, "_")
  end

  def with_message_locale(locale, charset)
    if locale
      old_locale = Locale.get
      GetText.locale = locale
    end
    if charset
      old_charset = Locale.charset
      GetText.charset = charset
    end
    begin
      yield
    ensure
      GetText.locale = old_locale if locale
      GetText.charset = old_charset if charset
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
    attrs = {}
    if lang
      attrs["lang"] = lang
      attrs["xml:lang"] = lang
    end
    gettext_encoding = encoding || "ISO-8859-1"
    with_message_locale(lang_to_gettext_locale(lang), gettext_encoding) do
      html_html(attrs) do
	generate_head
	generate_content
      end
    end
  end

  def generate_head
    html_head do
      html_title(title) unless title.nil?
      generate_links
      html_meta("name"=>"generator", "content"=>PROJECT_PAGE)
      unless encoding.nil?
        html_meta("http-equiv"=>"Content-Type",
	          "content"=>"text/html; charset=#{encoding}")
      end
      extra_metadata.each do |key, val|
	html_meta("name"=>key, "content"=>val)
      end
    end
  end

  def extra_metadata
    {}
  end

  def generate_scripts
    html_script("type"=>"text/javascript",
	     "src"=>base_path("quicknav.js")) { }
    html_script("type"=>"text/javascript") do
      comment("\ndocument.quicknavBasePath=\"#{base_path('index-files')}\";\n//")
    end
  end

  def generate_links
    html_link("rel"=>"stylesheet",
             "type"=>"text/css",
	     "href"=>base_path("style.css"),
	     "title"=>"JavaDoc")
    html_link("rel"=>"alternate stylesheet",
             "type"=>"text/css",
	     "href"=>base_path("unnatural.css"),
	     "title"=>"Unnatural")
    link_top do |title, href|
      html_link("rel"=>"top", "title"=>title, "href"=>href)
    end
    link_up do |title, href|
      html_link("rel"=>"up", "title"=>title, "href"=>href)
    end
    link_prev do |title, href|
      html_link("rel"=>"prev", "title"=>title, "href"=>href)
    end
    link_next do |title, href|
      html_link("rel"=>"next", "title"=>title, "href"=>href)
    end
  end

  def link_top; end
  def link_up; end
  def link_prev; end
  def link_next; end

  def link_for_type(type)
    if type.document?
      base_path(type.qualified_name.gsub(/\./, "/")+".html")
    else
      nil
    end
  end

  def link_type(type, qualified=false, attrs={})
    desc = type_description_for(type)
    attrs["title"] = desc unless desc.nil?
    if type.instance_of?(ASInterface)
      attrs["class"] = "interface_name"
    elsif type.instance_of?(ASClass)
      attrs["class"] = "class_name"
    elsif type == AS_VOID
      attrs["class"] = "void_name"
    end
    if qualified
      content = type.qualified_name
    else
      content = type.unqualified_name
    end
    href = link_for_type(type)
    if href
      attrs["href"] = href
      html_a(content, attrs)
    else
      html_span(content, attrs)
    end
  end

  def link_type_proxy(type_proxy, qualified=false)
    if type_proxy.resolved?
      link_type(type_proxy.resolved_type, qualified)
    else
      html_span(type_proxy.local_name, {"class"=>"unresolved_type_name"})
    end
  end

  def signature_for_method(method)
    sig = ""
    if method.access.static?
      sig << "static "
    end
    unless method.access.visibility.nil?
      sig << "#{method.access.visibility} "
    end
    sig << "function "
    sig << method.name
    sig << "("
    method.arguments.each_with_index do |arg, index|
      sig << ", " if index > 0
      sig << arg.name
      if arg.arg_type
	sig << ":"
	sig << arg.arg_type.name
      end
    end
    sig << ")"
    if method.return_type
      sig << ":"
      sig << method.return_type.name
    end
    sig
  end

  def type_description_for(as_type)
    if as_type.instance_of?(ASClass)
      _("Class %s") % as_type.qualified_name
    elsif as_type.instance_of?(ASInterface)
      _("Interface %s") % as_type.qualified_name
    end
  end

  def link_for_method(method)
    if @type == method.containing_type
      "##{method.name}"
    else
      type_href = link_for_type(method.containing_type)
      if type_href
	"#{type_href}##{method.name}"
      else
	nil
      end
    end
  end

  def link_method(method)
    sig = signature_for_method(method)
    if method.containing_type.document?
      html_a("href"=>link_for_method(method), "title"=>sig) do
	pcdata(method.name)
	pcdata("()")
      end
    else
      html_span("title"=>sig) do
	pcdata(method.name)
	pcdata("()")
      end
    end
  end

  def signature_for_field(field)
    sig = ""
    if field.access.static?
      sig << "static "
    end
    unless field.access.visibility.nil?
      sig << "#{field.access.visibility} "
    end
    sig << field.name
    if field.field_type
      sig << ":"
      sig << field.field_type.name
    end
    sig
  end

  def link_for_field(field)
    if @type == field.containing_type
      "##{field.name}"
    else
      type_href = link_for_type(field.containing_type)
      if type_href
	"#{type_href}##{field.name}"
      else
	nil
      end
    end
  end

  def link_field(field)
    sig = signature_for_field(field)
    if field.containing_type.document?
      html_a("href"=>link_for_field(field), "title"=>sig) do
	pcdata(field.name)
      end
    else
      html_span("title"=>sig) do
	pcdata(field.name)
      end
    end
  end

  def base_path(file)
    return file if @path_name.nil?
    ((".."+File::SEPARATOR) * @path_name.split(File::SEPARATOR).length) + file
  end

  def document_member?(member)
    !member.access.private?
  end

  def package_dir_for(package)
    if package.name
      package.name.gsub(/\./, "/")
    else
      ""
    end
  end

  def package_link_for(package, page)
    return page if package.default?
    package_dir_for(package) + "/" + page
  end

  def link_package_summary(package)
    name = package_display_name_for(package)
    href = package_link_for(package, "package-summary.html")
    title = package_description_for(package)
    html_a(name, {"href"=>href, "title"=>title, "class"=>"package_name"})
  end

  def package_display_name_for(package)
    return _("(Default)") if package.default?
    package.name
  end

  def package_description_for(package)
    _("Package %s") % package_display_name_for(package)
  end
end

class BasicPage < Page
  def initialize(conf, base_name, path_name=nil)
    super(base_name, path_name)
    @conf = conf
    @package = nil
    @navigation = nil
  end

  attr_accessor :navigation

  def astype; @type; end

  def aspackage; @package; end

  def generate_content
    html_body do
      generate_body_content
      generate_navigation
      generate_footer
    end
  end

  def generate_footer
    html_div("class"=>"footer") do
      html_a("as2api", {"href"=>PROJECT_PAGE, "title"=>_("ActionScript 2 API Documentation Generator")})
    end
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
      output_doccomment_linktag(inline)
    elsif inline.is_a?(CodeTag)
      output_doccomment_codetag(inline)
    else
      html_em(inline.inspect)
    end
  end

  def output_doccomment_linktag(inline)
    # FIXME: Seem to have missed generating title attribute in several cases,
    if inline.target && inline.member
      if inline.target.resolved?
	href = link_for_type(inline.target.resolved_type)
	if href
	  if inline.member =~ /\(/
	    target = "##{$`}"
	  else
	    target = "##{inline.member}"
	  end
	  href << target
	  html_a("href"=>href) do
	    if inline.text && inline.text!=""
	      pcdata(inline.text)
	    else
	      pcdata("#{inline.target.name}.#{inline.member}")
	    end
	  end
	else
	  if inline.text && inline.text!=""
	    pcdata(inline.text)
	  else
	    pcdata("#{inline.target.name}.#{inline.member}")
	  end
	end
      else
	pcdata("#{inline.target.name}##{inline.member}")
      end
    elsif inline.target
      # FIXME: doesn't handle case where we have some link text
      link_type_proxy(inline.target)
    else
      if inline.member =~ /\(/
        target = "##{$`}"
      else
        target = "##{inline.member}"
      end
      html_a("href"=>target) do
	if inline.text && inline.text!=""
	  pcdata(inline.text)
	else
	  pcdata(inline.member)
	end
      end
    end
  end

  def output_doccomment_codetag(inline)
    highlight = CodeHighlighter.new
    highlight.number_lines = false
    if inline.text =~ /[\n\r]/
      input = StringIO.new(inline.text)
      input.lineno = inline.lineno
      html_pre do
	highlight.highlight(input, self)
      end
    else
      input = StringIO.new(inline.text.strip)
      input.lineno = inline.lineno
      html_code do
	highlight.highlight(input, self)
      end
    end
  end

  def output_doccomment_initial_sentence(block)
    block.each_inline do |inline|
      if inline.is_a?(String)
	if inline =~ /(?:[\.:]\s+[A-Z])|(?:[\.:]\s+\Z)|(?:<\/?[Pp]\b)/
	  output_doccomment_inlinetag($`)
	  return
	else
	  output_doccomment_inlinetag(inline)
	end
      else
	output_doccomment_inlinetag(inline)
      end
    end
  end

  def generate_navigation
    # avoid empty list (illegal xhtml)
    return if @navigation.empty?

    html_ul("class"=>"main_nav", "id"=>"main_nav") do
      @navigation.each do |nav|
	link = nav.build_for_page(self)
	html_li do
	  if link.is_current
	    html_span(link.content, {"class"=>"button nav_current"})
	  else
	    if link.href
	      attrs = {"href"=>link.href, "class"=>"button"}
	      attrs["title"] = link.title if link.title
	      html_a(link.content, attrs)
	    else
	      if link.title
		html_span(link.content, {"title"=>link.title, "class"=>"button"})
	      else
		html_span(link.content, {"class"=>"button"})
	      end
	    end
	  end
	end
      end
    end
  end
end


def create_page(output_dir, page, format)
  if page.path_name
    dir = File.join(output_dir, page.path_name)
  else
    dir = output_dir
  end
  write_file(dir, page.base_name) do |io|
    if format
      out = XMLFormatter.new(XMLWriter.new(io))
      out.inlines ["span", "abbr", "acronym", "cite", "code", "dfn", "em", "kbd", "q", "samp", "strong", "var", "p", "address", "h1", "h2", "h3", "h4", "h5", "h6", "a", "dt", "dd", "li", "ins", "del", "bdo", "b", "big", "i", "small", "sub", "sup", "tt", "img", "th", "td",]
    else
      out = XMLWriter.new(io)
    end
    page.generate(out)
  end
end


# creates the pages in the given list by calling each object's #generate_page()
# method
def create_all_pages(conf, list)
  conf.progress_listener.generating_pages(list.length) do
    list.each_with_index do |page, index|
      page.title_extra = conf.title
      page.encoding = conf.input_encoding
      page.lang = conf.target_lang
      conf.progress_listener.generate_page(index, page)
      create_page(conf.output_dir, page, conf.format_html)
    end
  end
end


# vim:softtabstop=2:shiftwidth=2
