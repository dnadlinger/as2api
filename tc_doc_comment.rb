require 'test/unit'
require 'doc_comment'


class TC_DocComment < Test::Unit::TestCase
  def test_strip_stars()
    doc = DocComment.new
    initial = "foo = a * b\nbar!\n"
    with_stars = "********\n\t * #{initial}\t ********"
    assert_equal(initial, doc.strip_stars(with_stars))
  end
end
