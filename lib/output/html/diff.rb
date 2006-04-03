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

require 'output/html/html_framework'


class DiffOverviewNavLinkBuilder < NavLinkBuilder
  def href_on(page); page.base_path("changes/change-overview.html"); end

  def is_current?(page); page.is_a?(DiffOverviewPage); end

  def title_on(page)
    _("Overview of API Changes")
  end
end

class DiffPackageNavLinkBuilder < NavLinkBuilder
  def href_on(page)
    if page.aspackage
      "package-summary.html"
    else
      nil
    end
  end

  def is_current?(page); page.is_a?(PackageDiffIndexPage); end

  def title_on(page)
    if page.aspackage
      _("Overview of package %s") % page.package_display_name_for(page.aspackage)
    else
      nil
    end
  end
end


class DiffTypeNavLinkBuilder < NavLinkBuilder
  def href_on(page)
    if page.astype
      page.astype.unqualified_name+".html"
    else
      nil
    end
  end

  def is_current?(page); page.is_a?(TypeDiffPage); end

  def title_on(page)
    if page.astype
      _("Detail of %s API") % page.astype.qualified_name
    else
      nil
    end
  end
end


class BasicDiffPage < BasicPage

  def summary_table(rows, caption)
    summary_table_tr(rows, caption) do |row|
      html_td do
	yield row
      end
    end
  end

  def summary_table_tr(rows, caption)
    unless rows.nil? || rows.empty?
      html_table("class"=>"summary_list", "summary"=>"") do
	html_caption(caption)
	rows.each do |row|
	  html_tr do
	    yield row
	  end
	end
      end
    end
  end

  # overridden to exclude quicknav JS
  def generate_scripts; end

end

class DiffOverviewPage < BasicDiffPage
  def initialize(conf, api_changes)
    super(conf, "change-overview", "changes")
    @title = _("%s API Changes Between Versions %s and %s") % [api_changes.api_name, api_changes.api_old_ver, api_changes.api_new_ver]
    @api_changes = api_changes
  end

  def generate_body_content
    html_h1(@title)

    unless @api_changes
      html_p(_("No changes"))
      return
    end

    summary_table(@api_changes.added_packages, _("Added Packages")) do |as_package|
      name = package_display_name_for(as_package)
      pcdata(name)
    end

    summary_table_tr(@api_changes.modified_packages, _("Modified Packages")) do |as_package|
      html_td do
	name = package_display_name_for(as_package)
	href = package_link_for(as_package, "package-summary.html")
	html_a(name, {"href"=>href})
      end
      html_td do
	lastcount = 0
	if as_package.added_types?
	  pcdata(_("%d added") % as_package.added_types.length)
	  lastcount = as_package.added_types.length
	end
	if as_package.modified_types?
	  pcdata(", ") unless lastcount.zero?
	  pcdata(_("%d changed") % as_package.modified_types.length)
	  lastcount = as_package.modified_types.length
	end
	if as_package.removed_types?
	  pcdata(", ") unless lastcount.zero?
	  pcdata(_("%d removed") % as_package.removed_types.length)
	  lastcount = as_package.removed_types.length
	end
	pcdata(" ")
	pcdata(n_("type", "types", lastcount.to_i))
	pcdata(".")
      end
    end

    summary_table(@api_changes.removed_packages, _("Removed Packages")) do |as_package|
      name = package_display_name_for(as_package)
      pcdata(name)
    end
  end
end


class PackageDiffIndexPage < BasicDiffPage
  def initialize(conf, package_changes)
    dir = File.join("changes", package_dir_for(package_changes))
    super(conf, "package-summary", dir)
    @title = _("Package %s API Change Overview") % package_display_name_for(package_changes)
    @package_changes = package_changes
  end

  def generate_body_content
    html_h1(@title)

    summary_table_tr(@package_changes.added_types, _("Added Types")) do |as_type|
      #name = as_type.unqualified_name
      #pcdata(name)
      html_td do
	link_type(as_type)
      end
      html_td do
	if as_type.comment
	  output_doccomment_initial_sentence(as_type.comment.description)
	end
      end
    end

    summary_table_tr(@package_changes.modified_types, _("Modified Types")) do |as_type|
      html_td do
	name = as_type.new_type.unqualified_name
	href = "#{name}.html"
	html_a(name, {"href", href})
      end
      html_td do
	if as_type.added_methods? || as_type.modified_methods? || as_type.removed_methods?
	  lastcount = 0
	  if as_type.added_methods?
	    pcdata(_("%d added") % as_type.added_methods.length)
	    lastcount = as_type.added_methods.length
	  end
	  if as_type.modified_methods?
	    pcdata(", ") unless lastcount.zero?
	    pcdata(_("%d changed") % as_type.modified_methods.length)
	    lastcount = as_type.modified_methods.length
	  end
	  if as_type.removed_methods?
	    pcdata(", ") unless lastcount.zero?
	    pcdata(_("%d removed") % as_type.removed_methods.length)
	    lastcount = as_type.removed_methods.length
	  end
	  pcdata(" ")
	  pcdata(n_("method", "methods", lastcount.to_i))
	  pcdata(".")
	end
	if as_type.added_fields? || as_type.modified_fields? || as_type.removed_fields?
	  lastcount = 0
	  if as_type.added_fields?
	    pcdata(_("%d added") % as_type.added_fields.length)
	    lastcount = as_type.added_fields.length
	  end
	  if as_type.modified_fields?
	    pcdata(", ") unless lastcount.zero?
	    pcdata(_("%d changed") % as_type.modified_fields.length)
	    lastcount = as_type.modified_fields.length
	  end
	  if as_type.removed_fields?
	    pcdata(", ") unless lastcount.zero?
	    pcdata(_("%d removed") % as_type.removed_fields.length)
	    lastcount = as_type.removed_fields.length
	  end
	  pcdata(" ")
	  pcdata(n_("field", "fields", lastcount.to_i))
	  pcdata(".")
	end
      end
      html_td do
	if as_type.new_type.comment
	  output_doccomment_initial_sentence(as_type.new_type.comment.description)
	end
      end
    end

    summary_table(@package_changes.removed_types, _("Removed Types")) do |as_type|
      name = as_type.unqualified_name
      pcdata(name)
    end
  end

  def aspackage
    @package_changes
  end
end


class TypeDiffPage < BasicDiffPage
  def initialize(conf, type_changes)
    if type_changes.new_type.package_name
      dir = File.join("changes", type_changes.new_type.package_name.gsub(/\./, File::SEPARATOR))
    else
      dir = "changes"
    end

    super(conf, type_changes.new_type.unqualified_name, dir)
    @title = _("%s API Change Overview") % type_changes.new_type.unqualified_name
    @type_changes = type_changes
  end

  def aspackage
    @type_changes.new_type.package
  end

  def generate_body_content
    html_h1(@title)

    summary_table_tr(@type_changes.added_fields, _("Added Fields")) do |as_field|
      html_td do
	pcdata(as_field.name)
      end
      html_td do
	if as_field.comment
	  output_doccomment_initial_sentence(as_field.comment.description)
	end
      end
    end

    summary_table_tr(@type_changes.modified_fields, _("Modified Fields")) do |field_changes|
      html_td do
	pcdata(field_changes.name)
      end
      html_td do
	generate_visibility_change(field_changes)
	generate_static_change(field_changes)
	generate_type_change(_("Field"), field_changes)
	generate_readwrite_change(field_changes)
      end
    end

    summary_table(@type_changes.removed_fields, _("Removed Fields")) do |as_field|
      pcdata(as_field.name)
    end

    summary_table_tr(@type_changes.added_methods, _("Added Methods")) do |as_method|
      html_td do
	pcdata(as_method.name)
      end
      html_td do
	if as_method.comment
	  output_doccomment_initial_sentence(as_method.comment.description)
	end
      end
    end

    summary_table_tr(@type_changes.modified_methods, _("Modified Methods")) do |method_changes|
      html_td do
	pcdata(method_changes.name)
      end
      html_td do
	generate_visibility_change(method_changes)
	generate_static_change(method_changes)
	generate_type_change(_("Return"), method_changes)
	generate_args_change(method_changes)
      end
    end

    summary_table(@type_changes.removed_methods, _("Removed Methods")) do |as_method|
      pcdata(as_method.name)
    end
  end

  def generate_visibility_change(field_changes)
    if field_changes.visibility_change
      pcdata(_("Visibility changed from "))
      html_code(field_changes.visibility_change.old_vis.to_s)
      pcdata(_(" to "))
      html_code(field_changes.visibility_change.new_vis.to_s)
      pcdata(". ")
    end
  end

  def generate_static_change(field_changes)
    if field_changes.static_change
      if field_changes.static_change.new_flag
	pcdata(_("Is now"))
      else
	pcdata(_("Is no longer"))
      end
      pcdata(" ")
      html_code("static")
      pcdata(". ")
    end
  end

  def generate_type_name(name)
      if name
	html_code(name)
      else
	pcdata(_("unspecified"))
      end
  end

  def generate_type_change(kind, field_changes)
    if field_changes.type_change
      pcdata(kind)
      pcdata(_(" type changed from "))
      generate_type_name(field_changes.type_change.old_type_name)
      pcdata(_(" to "))
      generate_type_name(field_changes.type_change.new_type_name)
      pcdata(". ")
    end
  end

  def generate_readwrite_change(field_changes)
    change = field_changes.readwrite_change
    if change
      if change.old_read != change.new_read
	if change.new_read
	  pcdata(_("Is now readable"))
	else
	  pcdata(_("Is no longer readable"))
	end
      end
      if change.old_write != change.new_write
	if change.new_write
	  pcdata(_("Is now writeable"))
	else
	  pcdata(_("Is no longer writeable"))
	end
      end
    end
  end

  def generate_args_change(method_changes)
    changes = method_changes.args_change
    if changes
      pcdata(_("Argument list changed from "))
      list_args(changes.old_args)
      pcdata(_(" to "))
      list_args(changes.new_args)
      pcdata(".")
    end
  end

  def list_args(args)
    html_code do
      pcdata("(")
      first = true
      args.each do |arg|
	if first
	  first = false
	else
	  pcdata(", ")
	end
	pcdata(arg.name)
	if arg.arg_type
	  pcdata(":")
	  pcdata(arg.arg_type.name)
	end
      end
      pcdata(")")
    end
  end
end

def build_navigation
  elements = []
  elements << DiffOverviewNavLinkBuilder.new(nil, N_("Overview"))
  elements << DiffPackageNavLinkBuilder.new(nil, N_("Package"))
  elements << DiffTypeNavLinkBuilder.new(nil, N_("Class"))
  elements
end

def make_diff_pages(conf, api_changes)
  list = []

  list << DiffOverviewPage.new(conf, api_changes)

  if api_changes
    api_changes.modified_packages.each do |package_changes|
      list << PackageDiffIndexPage.new(conf, package_changes)

      package_changes.modified_types.each do |type_changes|
	list << TypeDiffPage.new(conf, type_changes)
      end
    end
  end

  nav = build_navigation
  list.each { |page| page.navigation = nav if page.is_a?(BasicPage) }

  list
end

def generate_diffs(conf, api_changes)
  list = make_diff_pages(conf, api_changes)
  create_all_pages(conf, list)
end


# vim:softtabstop=2:shiftwidth=2
