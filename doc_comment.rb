
class DocComment
  def DocComment.method(text)
    doc = DocComment.new
    doc.extract_method_doc(text)
    doc
  end

  def DocComment.type(text)
    doc = DocComment.new
    doc.extract_type_doc(text)
    doc
  end

  def initialize
    @description = nil
    @params = {}
    @desc_return = nil
    @see_also = []
    @exceptions = {}
  end

  def extract_method_doc(text)
    text = strip_stars(text)
  end

  # strips leading stars (and any preceeding whitespace) from lines of
  # comment text
  def parse(input)
    state = :DESCRIPTION
    description = ''
    lines = input.split(/\n\r|\n|\r/)
    while text = lines.shift
      text = strip_stars(text)
      break if text =~ /^\s*@/
      description << "\n" unless description==''
      description << text
    end
    state = nil
    desc_return = nil
    desc_throws = nil
    desc_param = nil
    seealso = nil
    while text
      text = strip_stars(text)
      unless text =~ /^\s*$/
        case text
          when /^\s*@param ([^ ]+)/
	    state = :PARAM
	    desc_param = $'
	    add_param($1, desc_param)
	  when /^\s*@return /
	    state = :RETURN
	    desc_return = $'
	  when /^\s*@see /
	    state = :SEE
	    seealso = $'
	    add_seealso(seealso)
	  when /^\s*@throws ([^ ]+)/
	    state = :THROWS
	    desc_throws = $'
	    add_exception($1, desc_throws)
	  else
	    case state
	      when :PARAM
	        desc_param << "\n" << text
	      when :RETURN
		desc_return << "\n" << text
	      when :SEE
		seealso << "\n" << text
	      when :THROWS
		desc_throws << "\n" << text
	    end
        end
      end
      text = lines.shift
    end
    self.desc_return = desc_return
    self.description = description
  end

  def add_param(name, desc)
    @params[name] = desc
  end

  def add_seealso(text)
    @see_also << text
  end

  def seealso_a
    @see_also
  end

  def seealso?
    !@see_also.empty?
  end

  def each_see_also
    @see_also.each do |also|
      yield also
    end
  end

  def strip_stars(text)
    text.sub(/\A\s*\**/, "").sub(/\s*\Z/, "")
  end

  attr_accessor :desc_return, :description

  def param(name)
    @params[name]
  end

  def parameters?
    !@params.empty?
  end

  def add_exception(type, desc)
    # NB: desc may get modified by the called after this method is invoked
    @exceptions[type] = desc
  end

  def each_exception
    @exceptions.each do |type, desc|
      yield type, desc
    end
  end

  def describe_exception(type)
    @exceptions[type]
  end

  def exceptions?
    !@exceptions.empty?
  end
end
