
require 'localisation/xliff/xliff_reader'
require 'localisation/xliff/xliff_doc_utils'

class CodePhHandler
  def initialize(block); @block = block; end
  def start_ph; @text=""; end
  def end_ph; @block.add_inline(CodeTag.new(0, @text)); end
  def text(text); @text<<text end
end

class LinkPhHandler
  def initialize(block, type_resolver)
    @block = block
    @type_resolver = type_resolver
  end
  def start_ph; @text=@ph_text=""; @sub_text="" end
  def end_ph;
    @ph_text =~ /^([^#\s]+)(?:#([^\s]+))?/
    if $1
      target = @type_resolver.resolve($1)
    else
      target = nil
    end
    member = $2
    @block.add_inline(LinkTag.new(0, target, member, @sub_text)) 
  end
  def text(text); @text<<text end
  def start_sub; @text=@sub_text; end
  def end_sub; @text=@ph_text; end
end

class DocXliffHandler
  include TranslationHandler

  def initialize(filename_to_type, target_lang)
    @filename_to_type = filename_to_type
    @target_lang = target_lang
    @current_type = nil
  end

  def start_file(file)
    @current_type = @filename_to_type[file.original]
    if @current_type.nil?
      warn("no type matched #{file.original.inspect}")
    end
    if file.target_language == @target_lang
      @process_this_file = true
    else
      @process_this_file = false
      warn("target language #{file.target_language.inspect} for #{file.original.inspect} isn't #{@target_lang.inspect}; skipping translation data")
    end
  end
  def end_file
    @current_type = nil
  end


  def get_seeblock(comment, index)
    i = 0
    comment.each_seealso do |block|
      return block if index == i
      i += 1
    end
    return nil
  end

  def start_trans_unit(id)
    return unless @process_this_file
    parts = id.split(/-/)
    element = parts.shift
    unless element == "class" || element == "interface"
      warn("expected id to start with 'class-' or 'interface-'")
      return
    end
    type_name = XliffIds.from_id(parts.shift)
    unless type_name == @current_type.qualified_name
      warn("expected type didn't match type in id; #{@current_type.qualified_name.inspect}, #{type_name.inspect}")
      return
    end
    element = parts.shift
    case element
      when "description"
	@current_block = @current_type.comment.description
      when "method"
	method_name = XliffIds.from_id(parts.shift)
	asmethod = @current_type.get_method_called(method_name)
	element = parts.shift
	case element
	  when "description"
	    @current_block = asmethod.comment.description
	  when "return"
	    @current_block = asmethod.comment.find_return
	  when "param"
	    param_name = XliffIds.from_id(parts.shift)
	    @current_block = asmethod.comment.find_param(param_name)
	  when "throws"
	    type_name = XliffIds.from_id(parts.shift)
	    @current_block = asmethod.comment.find_throws(type_name)
	  when "see"
	    see_num = parts.shift.to_i
	    @current_block = get_seeblock(asmethod.comment, see_num)
	  else
	    warn("unknown API element #{element.inspect} in id #{id.inspect}")
	    return
	end
      when "field"
	field_name = XliffIds.from_id(parts.shift)
	asfield = @current_type.get_field_called(field_name)
	unless asfield
	  warn("no field #{field_name.inspect} in #{@current_type.qualified_name}")
	  return
	end
	element = parts.shift
	case element
	  when "description"
	    @current_block = asfield.comment.description
	  when "see"
	    see_num = parts.shift.to_i
	    @current_block = get_seeblock(asfield.comment, see_num)
	  else
	    warn("unknown API element #{element.inspect} in id #{id.inspect}")
	    return
	end
      when "see"
	see_num = parts.shift.to_i
	@current_block = get_seeblock(@current_type.comment, see_num)
      else
	warn("unknown API element #{element.inspect} in id #{id.inspect}")
	return
    end
  end

  def end_trans_unit
    return unless @process_this_file
    @current_block = nil
  end

  def start_target
    return unless @process_this_file
    @current_block.clear if @current_block
  end

  def text(text)
    return unless @process_this_file
    @current_block.add_inline(text) if @current_block
  end

  def ph(id)
    # Null-Object pattern,
    return PhHandler.new unless @current_block && @process_this_file

    case id
      when "code"
	return CodePhHandler.new(@current_block)
      when "link"
	return LinkPhHandler.new(@current_block, @current_type.type_resolver)
      else
	raise "unhandled placeholder id #{id.inspect}"
    end
  end

  private

  def warn(text)
    $stderr.puts("warn: #{text} (#{caller[0]})")
  end
end


def update_docs(conf, type_aggregator)
  filename_to_type = {}
  type_aggregator.each_type do |astype|
    filename_to_type[astype.input_filename] = astype
  end
  File.open(conf.xliff_import) do |io|
    doc_handler = DocXliffHandler.new(filename_to_type, conf.target_lang)
    XLIFFReader.new(io, doc_handler).parse
  end
end


# vim:sw=2:sts=2
