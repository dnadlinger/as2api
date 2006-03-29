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


require 'set'

require 'output/html/html_framework'


GetText.bindtextdomain("as2api")

class IndexTerm
  def <=>(other)
    cmp = term.downcase <=> other.term.downcase
    cmp = term <=> other.term if cmp == 0
    cmp
  end
end

class TypeIndexTerm < IndexTerm
  def initialize(astype)
    @astype = astype
  end

  def term
    @astype.unqualified_name
  end

  def link(out)
    out.link_type(@astype)
    out.pcdata(_(" in package "))
    out.html_a(out.package_display_name_for(@astype.package), {"href"=>"../" + @astype.package_name.gsub(".", "/") + "/package-summary.html"})
  end
end

class MemberIndexTerm < IndexTerm
  def initialize(astype, asmember)
    @astype = astype
    @asmember = asmember
  end

  def term
    @asmember.name
  end
end

class MethodIndexTerm < MemberIndexTerm
  def link(out)
    out.link_method(@asmember)
    out.pcdata(_(" method in "))
    out.link_type(@astype, true)
  end
end

class FieldIndexTerm < MemberIndexTerm
  def link(out)
    out.link_field(@asmember)
    out.pcdata(_(" field in "))
    out.link_type(@astype, true)
  end
end


class IndexNavLinkBuilder < NavLinkBuilder
  def href_on(page); page.base_path("index-files/index.html"); end

  def is_current?(page) page.is_a?(IndexPage); end

  def title_on(page); _("Alpabetical index of types and members"); end
end

class Indexer
  def create_index(type_agregator)
    index = []
    initials = Set.new
    # TODO: include packages
    type_agregator.each_type do |astype|
      if astype.document?
	index << TypeIndexTerm.new(astype)
	initials << astype.unqualified_name.upcase[0]
	astype.each_method do |asmethod|
	  if document_member?(asmethod)
	    index << MethodIndexTerm.new(astype, asmethod)
	    initials << asmethod.name.upcase[0]
	  end
	end
	if astype.is_a?(ASClass)
	  astype.each_field do |asfield|
	    if document_member?(asfield)
	      index << FieldIndexTerm.new(astype, asfield)
	      initials << asfield.name.upcase[0]
	    end
	  end
	end
      end
    end

    @index = index.sort!
    @initials = initials
  end

  attr_reader :index, :initials

  private

  def document_member?(member)
    !member.access.private?
  end
end

class IndexPage < BasicPage
  def initialize(conf, indexer)
    super(conf, "index", "index-files")
    @indexer = indexer
    @title = _("Alphabetical Index")
  end

  def extra_metadata
    # no point in search engines indexing our index,
    {
      "robots" => "noindex"
    }
  end


  def generate_body_content
    html_p do
      @indexer.initials.to_a.sort.each do |initial|
	i = initial.chr
	html_a(i, {"href"=>"##{i}"})
	pcdata(" ")
      end
    end

    last_initial = nil
    @indexer.index.each do |element|
      initial = element.term.upcase[0]
      if initial != last_initial
	html_h2 do
	  html_a("", {"name"=>initial.chr})
	  pcdata(initial.chr)
	end
	last_initial = initial
      end
      html_p do
	element.link(self)
      end
    end
  end

  def link_top
    yield _("Overview"), base_path("overview-summary.html")
  end
end

# vim:softtabstop=2:shiftwidth=2
