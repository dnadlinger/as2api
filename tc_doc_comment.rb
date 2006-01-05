require 'test/unit'
require 'doc_comment'
require 'api_loader'

class TC_DocComment < Test::Unit::TestCase
  def test_description()
    text = "foo bar\n *blat\n * @param foo bar\n blat ping pong\n *"
    comment_data = parse_it(text)
    assert_equal("foo bar\nblat", comment_data[0].inlines[0].strip)
  end

  def test_params()
    text = "*\n * @param foo bar\n blat ping pong\n *"
    comment_data = parse_it(text)
    expected = ParamBlockTag.new();
    expected.param_name = "foo"
    expected.add_inline("bar\n blat ping pong\n")
    assert_equal(expected, comment_data[1])
  end

  def test_return()
    text = "*\n * @return foo bar\n blat\n *"
    comment_data = parse_it(text)
    expected = ReturnBlockTag.new();
    expected.add_inline(" foo bar\n blat\n")
    assert_equal(expected, comment_data[1])
  end

  def test_see()
    text = "*\n * @see foo bar\n blat\n *"
    comment_data = parse_it(text)
    expected = BlockTag.new
    expected.add_inline("\n ")
    assert_equal(expected, comment_data[0])
    expected = SeeBlockTag.new
    expected.add_inline("foo bar\nblat")
    assert_equal(expected, comment_data[1])
    #assert(doc.seealso_a.member?(expected), "@see didn't have #{expected.inspect}")
  end

  def test_throws()
    text = "*\n * @throws foo.Bbar blat\nping\n *"
    comment_data = parse_it(text)
    expected = ThrowsBlockTag.new();
    expected.add_inline("blat\nping")
    assert(expected, comment_data[1])
  end

#  def test_package_html
#    [
#      "<html><body>test</body></html>",
#      "<body>te<b>st</b></body>"
#    ].each do |text|
#      PackageHTML.process(text) do |element|
#	a = REXML::XPath.match(element, "descendant::text()").join
#        assert_equal("test", a)
#      end
#    end
#  end

  def parse_it(text)
    comment_data = CommentData.new

    input = StringIO.new(text)
    input.lineno = 1
    lexer = ActionScript::ParseDoc::DocCommentLexer.new(input)
    lexer.source = caller.last
    parser = ActionScript::ParseDoc::DocCommentParser.new(lexer)
    parse_conf_build = ConfigBuilder.new
    config = parse_conf_build.build_method_config
    type_resolver = LocalTypeResolver.new(nil)
    handler = OurDocCommentHandler.new(comment_data, config, type_resolver)
    parser.handler = handler

    parser.parse_comment

    comment_data
  end
end
