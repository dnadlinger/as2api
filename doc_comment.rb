

class CommentInput
  def initialize(text, lineno, type_resolver)
    @text = text
    @lineno = lineno
    @type_resolver = type_resolver
  end

  attr_accessor :text, :lineno, :type_resolver

  def derive(text, lineno=nil)
    lineno = @lineno if lineno.nil?
    return CommentInput.new(text, lineno, @type_resolver)
  end
end


class DocCommentParser
  def initialize(config)
    @config = config
  end

  def parse(input)
    data = CommentData.new
    @config.begin_comment(data)
    lines = input.text.split(/\n\r|\n|\r/)
    lineno = input.lineno
    while text = lines.shift
      parse_line(input.derive(strip_stars(text), lineno))
      lineno += 1
    end
    @config.end_comment
    return data
  end

  private

  def strip_stars(text)
    text.sub(/\A\s*\**/, "").sub(/\s*\Z/, "")
  end

  def parse_line(input)
    if input.text =~ /^\s*@([a-zA-Z]+)\s*/
      @config.begin_block($1)
      @config.parse(input.derive($'))
    else
      @config.parse(input)
    end
  end
end


class CommentData
  def initialize
    @blocks = []
  end

  def add_block(block)
    @blocks << block
  end

  def each_block
    @blocks.each do |block|
      yield block
    end
  end

  def [](i)
    @blocks[i]
  end
end


class DocCommentParserConfig
  def initialize
    @block_handlers = {}
  end

  def begin_comment(comment_data)
    @comment_data = comment_data
    @block = @description_block_handler
    beginning_of_block
  end

  def add_block_parser(name, handler)
    @block_handlers[name] = handler
    handler.handler = self
  end

  def description_handler=(handler)
    @description_block_handler = handler
  end

  def end_comment
    end_of_block
  end

  def begin_block(kind)
    end_of_block
    @block = handler_for(kind)
    beginning_of_block
  end

  def parse(text)
    @block.parse_line(text)
  end

  def parse_error(msg)
    $stderr.puts(msg)
  end

  private

  def handler_for(kind)
    handler = @block_handlers[kind]
    if handler.nil?
      parse_error("Unknown block tag @#{kind}")
      handler = NIL_HANDLER
    end
    handler
  end

  def beginning_of_block
    @block.begin_block
  end

  def end_of_block
    data = @block.end_block
    @comment_data.add_block(data) unless data.nil?
  end
end


class LinkTag
  def initialize(target, member, text)
    @target = target
    @member = member
    @text = text
  end

  attr_accessor :target, :member, :text
end


class BlockTag
  def initialize
    @inlines = []
  end

  def add_inline(inline)
    @inlines << inline
  end

  def each_inline
    @inlines.each do |inline|
      yield inline
    end
  end
end


class ParamBlockTag < BlockTag
  attr_accessor :param_name
end


class ThrowsBlockTag < BlockTag
  attr_accessor :exception_type
end


class SeeBlockTag < BlockTag
end


class ReturnBlockTag < BlockTag
end


class InlineParser
  def parse(block_data, inpu)
    raise "implement me"
  end
end


# creates a LinkTag inline
def create_link(input)
  if input.text =~ /^([^ ]+(?:\([^\)]*\))?)\s*/
    target = $1
    text = $'
    # TODO: need a MemberProxy (and maybe Method+Field subclasses) with similar
    #       role to TypeProxy, to simplify this, and output_doccomment_inlinetag
    if target =~ /([^#]*)#(.*)/
      type_name = $1
      member_name = $2
    else
      type_name = target
      member_name = nil
    end
    if type_name == ""
      type_proxy = nil
    else
      type_proxy = input.type_resolver.resolve(type_name, input.lineno)
    end
    return LinkTag.new(type_proxy, member_name, text)
  end
  return nil
end


class LinkInlineParser < InlineParser
  def parse(block_data, input)
    link = create_link(input)
    if link.nil?
      block_data.add_inline("{@link #{input.text}}")
    else
      block_data.add_inline(link)
    end
  end
end


class BlockParser
  def initialize
    @inline_parsers = {}
    @data = nil
  end

  attr_accessor :handler

  def begin_block
  end

  def parse_line(text)
  end

  def end_block
    @data
  end

  def add_inline_parser(tag_name, parser)
    @inline_parsers[tag_name] = parser
  end

  def parse_inlines(input)
    text = input.text
    while text.length > 0
      if text =~ /\A\{@([^}\s]+)\s*([^}]*)\}/
	tag_name = $1
	tag_data = $2
	inline_parser = @inline_parsers[tag_name]
	if inline_parser.nil?
	  add_text($&)
	else
	  inline_parser.parse(@data, input.derive(tag_data))
	end
	text = $'
      elsif text =~ /\A.[^{]*/
	add_text($&)
	text = $'
      else
	raise "#{input.lineno}: no match for #{text.inspect}"
      end
    end
  end

  def add_text(text)
    @data.add_inline(text)
  end
end


NIL_HANDLER = BlockParser.new


class ParamParser < BlockParser
  def begin_block
    @data = ParamBlockTag.new
  end

  def parse_line(input)
    if @data.param_name.nil?
      input.text =~ /\s*([^\s]+)\s+/
      @data.param_name = $1
      input = input.derive($')
    end
    parse_inlines(input)
  end
end


class ThrowsParser < BlockParser
  def begin_block
    @data = ThrowsBlockTag.new
  end

  def parse_line(input)
    if @data.exception_type.nil?
      input.text =~ /\A\s*([^\s]+)\s+/
      @data.exception_type = input.type_resolver.resolve($1)
      input = input.derive($')
    end
    parse_inlines(input)
  end
end


class ReturnParser < BlockParser
  def begin_block
    @data = ReturnBlockTag.new
  end
  def parse_line(input)
    parse_inlines(input)
  end
end


class DescriptionParser < BlockParser
  def begin_block
    @data = BlockTag.new
  end
  def parse_line(input)
    parse_inlines(input)
  end
end


class SeeParser < BlockParser
  def begin_block
    @data = nil
  end

  def parse_line(input)
    if @data.nil?
      @data = SeeBlockTag.new
      input.text =~ /\A\s*/
      case $'
	when /['"]/
	  # plain, 'string'-like see entry
	  @data.add_inline(input.text)
	when /</
	  # HTML entry
	  @data.add_inline(input.text)
	else
	  # 'link' entry
	  link = create_link(input)
	  if link.nil?
	    @data.add_inline(input.text)
	  else
	    @data.add_inline(link)
	  end
      end
    else
      @data.add_inline(input.text)
    end
  end
end


#############################################################################


class ConfigBuilder
  def build_method_config
    config = build_config
    add_standard_block_parsers(config)
    config.add_block_parser("param", build_param_block_parser)
    config.add_block_parser("return", build_return_block_parser)
    config.add_block_parser("throws", build_throws_block_parser)
    return config
  end

  def build_field_config
    config = build_config
    add_standard_block_parsers(config)
    return config
  end

  def build_type_config
    config = build_config
    add_standard_block_parsers(config)
    return config
  end

  protected

  def build_config
    DocCommentParserConfig.new
  end

  def add_standard_block_parsers(config)
    config.description_handler=build_description_block_parser
    config.add_block_parser("see", build_see_block_parser)
  end

  def add_common_inlines(block_parser)
    block_parser.add_inline_parser("link", LinkInlineParser.new)
  end

  def build_description_block_parser
    parser = DescriptionParser.new
    add_common_inlines(parser)
    parser
  end

  def build_param_block_parser
    parser = ParamParser.new
    add_common_inlines(parser)
    parser
  end

  def build_return_block_parser
    parser = ReturnParser.new
    add_common_inlines(parser)
    parser
  end

  def build_throws_block_parser
    parser = ThrowsParser.new
    add_common_inlines(parser)
    parser
  end

  def build_see_block_parser
    parser = SeeParser.new
    add_common_inlines(parser)
    parser
  end
end

# vim:softtabstop=2:shiftwidth=2
