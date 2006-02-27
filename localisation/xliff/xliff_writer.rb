
module XLIFFWriter
  private

  TAGS = [
    "alt-trans",
    "bin-source",
    "bin-target",
    "bin-unit",
    "body",
    "bpt",
    "bx",
    "context",
    "context-group",
    "count",
    "count-group",
    "ept",
    "ex",
    "external-file",
    "file",
    "g",
    "glossary",
    "group",
    "header",
    "internal-file",
    "it",
    "mrk",
    "note",
    "ph",
    "phase",
    "phase-group",
    "prop",
    "prop-group",
    "reference",
    "skl",
    "source",
    "sub",
    "target",
    "tool",
    "trans-unit",
    "x",
    "xliff"
  ]


  TAGS.each do |name|
    class_eval <<-HERE
      def xliff_#{name.gsub(/-/, "_")}(*args)
	if block_given?
	  @io.element("#{name}", *args) { yield }
	else
	  if args.length == 0
	    @io.empty_tag("#{name}")
	  else
	    if args[0].instance_of?(String)
	      @io.simple_element("#{name}", *args)
	    else
	      @io.empty_tag("#{name}", *args)
	    end
	  end
	end
      end
    HERE
  end

  public

  def pcdata(text)
    @io.pcdata(text)
  end

  def pi(text)
    @io.pi(text)
  end

  def comment(text)
    @io.comment(text)
  end

  def doctype(name, syspub, public_id, system_id)
    @io.doctype(name, syspub, public_id, system_id)
  end

  def passthrough(text)
    @io.passthrough(text)
  end

  def xml; @io end
end
