
class DocComment
  def DocComment.method(text)
    doc = DocComment.new
    doc.extract_method_doc
    doc
  end

  def DocComment.type(text)
    doc = DocComment.new
    doc.extract_type_doc
    doc
  end


  def extract_method_doc(text)
    text = strip_stars(text)
  end

  # strips leading stars (and any preceeding whitespace) from lines of
  # comment text
  def parse(text)
    state = :DESCRIPTION
    description = ''
    text.each_line do |line|
      line = line.sub(/\A\s*\*+\s*/, "").sub(/\s*\Z/, "")
      case state
        when :DESCRIPTION
	  
      end
    end
  end
end
