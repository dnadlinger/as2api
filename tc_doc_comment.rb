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
    assert(comment_data.has_params?, "should have @param tag")
    expected = ParamBlockTag.new();
    expected.param_name = "foo"
    expected.add_inline("bar\n blat ping pong\n")
    assert_equal(expected, comment_data[1])
  end

  def test_return()
    text = "*\n * @return foo bar\n blat\n *"
    comment_data = parse_it(text)
    assert(comment_data.has_return?, "should have @return tag")
    expected = ReturnBlockTag.new();
    expected.add_inline(" foo bar\n blat\n")
    assert_equal(expected, comment_data[1])
  end

  def test_see()
    text = "*\n * @see foo bar\n blat\n *"
    comment_data = parse_it(text)
    assert(comment_data.has_seealso?, "should have @see tag")
    expected = SeeBlockTag.new
    type_proxy = TypeProxy.new(nil, "foo")
    type_proxy.lineno=2
    link = LinkTag.new(2, type_proxy, nil, "bar\n blat\n")
    link.lineno=2
    expected.add_inline(link)
    assert_equal(expected, comment_data[1])
    #assert(doc.seealso_a.member?(expected), "@see didn't have #{expected.inspect}")
  end

  def test_throws()
    text = "*\n * @throws foo.Bbar blat\nping\n *"
    comment_data = parse_it(text)
    assert(comment_data.has_exceptions?, "should have @throws tag")
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
    type_namespace = TypeLocalNamespace.new(nil)
    handler = OurDocCommentHandler.new(comment_data, config, type_namespace)
    parser.handler = handler

    parser.parse_comment

    comment_data
  end
end
