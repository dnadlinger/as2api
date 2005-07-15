require 'test/unit'
require 'doc_comment'
require 'api_loader'

class TC_DocComment < Test::Unit::TestCase
  def test_strip_stars()
    doc = DocComment.new(LocalTypeResolver.new)
    initial = "foo = a * b\nbar!"
    with_stars = "\t **#{initial}"
    assert_equal(initial, doc.strip_stars(with_stars))
  end

  def test_description()
    doc = DocComment.new(LocalTypeResolver.new)
    text = "foo bar\n *blat\n * @param foo bar\n blat ping pong\n *"
    doc.parse(text)
    assert_equal("foo bar\nblat", doc.description)
  end

  def test_params()
    doc = DocComment.new(LocalTypeResolver.new)
    text = "*\n * @param foo bar\n blat ping pong\n *"
    doc.parse(text)
    assert_equal("bar\nblat ping pong", doc.param("foo"))
  end

  def test_return()
    doc = DocComment.new(LocalTypeResolver.new)
    text = "*\n * @return foo bar\n blat\n *"
    doc.parse(text)
    assert_equal("foo bar\nblat", doc.desc_return)
  end

  def test_see()
    doc = DocComment.new(LocalTypeResolver.new)
    text = "*\n * @see foo bar\n blat\n *"
    doc.parse(text)
    expected = "foo bar\nblat"
    assert(doc.seealso_a.member?(expected), "@see didn't have #{expected.inspect}")
  end

  def test_throws()
    doc = DocComment.new(LocalTypeResolver.new)
    text = "*\n * @throws foo.Bbar blat\nping\n *"
    doc.parse(text)
    assert("blat\nping", doc.describe_exception("foo.Bar"))
  end

  def test_package_html
    [
      "<html><body>test</body></html>",
      "<body>te<b>st</b></body>"
    ].each do |text|
      PackageHTML.process(text) do |element|
	a = REXML::XPath.match(element, "descendant::text()").join
        assert_equal("test", a)
      end
    end
  end
end
