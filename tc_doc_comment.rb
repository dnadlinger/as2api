require 'test/unit'
require 'doc_comment'


class TC_DocComment < Test::Unit::TestCase
  def test_strip_stars()
    doc = DocComment.new
    initial = "foo = a * b\nbar!"
    with_stars = "\t **#{initial}"
    assert_equal(initial, doc.strip_stars(with_stars))
  end

  def test_description()
    doc = DocComment.new
    text = "foo bar\n *blat\n * @param foo bar\n blat ping pong\n *"
    doc.parse(text)
    assert_equal("foo bar\nblat", doc.description)
  end

  def test_params()
    doc = DocComment.new
    text = "*\n * @param foo bar\n blat ping pong\n *"
    doc.parse(text)
    assert_equal("bar", doc.param("foo"))
    assert_equal("ping pong", doc.param("blat"))
  end

  def test_return()
    doc = DocComment.new
    text = "*\n * @return foo bar\n blat\n *"
    doc.parse(text)
    assert_equal("foo bar\nblat", doc.desc_return)
  end

  def test_see()
    doc = DocComment.new
    text = "*\n * @see foo bar\n blat\n *"
    doc.parse(text)
    expected = "foo bar\nblat"
    assert(doc.seealso_a.member?(expected), "@see didn't have #{expected.inspect}")
  end

  def test_throws()
    doc = DocComment.new
    text = "*\n * @throws foo.Bbar blat\nping\n *"
    doc.parse(text)
    assert("blat\nping", doc.describe_exception("foo.Bar"))
  end
end
