# 
# Part of as2api - http://www.badgers-in-foil.co.uk/projects/as2api/
#
# Copyright (c) 2006 David Holroyd, and contributors.
#
# See the file 'COPYING' for terms of use of this code.
#

require 'output/html/html_framework'

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

end

class DiffOverviewPage < BasicDiffPage
  def initialize(conf, api_changes)
    super(conf, "change-summary", "changes")
    @title = _("API Change Overview")
    @api_changes = api_changes
  end

  def generate_body_content
    html_h1(_("API Change Overview"))

    unless @api_changes
      html_p(_("No changes"))
      return
    end

    summary_table(@api_changes.added_packages, _("Added Packages")) do |as_package|
      name = package_display_name_for(as_package)
      href = File.join("..", package_link_for(as_package, "package-summary.html"))
      html_a(name, {"href"=>href})
    end

    summary_table(@api_changes.modified_packages, _("Modified Packages")) do |as_package|
      name = package_display_name_for(as_package)
      href = package_link_for(as_package, "change-summary.html")
      html_a(name, {"href", href})
    end

    summary_table(@api_changes.removed_packages, _("Removed Packages")) do |as_package|
      name = package_display_name_for(as_package)
      pcdata(name)
    end
  end

  def navigation
    html_ul("class"=>"main_nav") do
      # TODO
    end
  end
end


class PackageDiffIndexPage < BasicDiffPage
  def initialize(conf, package_changes)
    dir = File.join("changes", package_dir_for(package_changes))
    super(conf, "change-summary", dir)
    @title = _("Package %s API Change Overview") % package_display_name_for(package_changes)
    @package_changes = package_changes
  end

  def generate_body_content
    html_h1(@title)

    summary_table(@package_changes.added_types, _("Added Types")) do |as_type|
      name = as_type.unqualified_name
      pcdata(name)
    end

    summary_table(@package_changes.modified_types, _("Modified Types")) do |as_type|
      name = as_type.new_type.unqualified_name
      href = "#{name}.html"
      html_a(name, {"href", href})
    end

    summary_table(@package_changes.removed_types, _("Removed Types")) do |as_type|
      name = as_type.unqualified_name
      pcdata(name)
    end
  end

  def navigation
    html_ul("class"=>"main_nav") do
      # TODO
    end
  end
end


class TypeDiffPage < BasicDiffPage
  def initialize(conf, type_changes)
    dir = File.join("changes", type_changes.new_type.package_name.gsub(/\./, "/"))
    super(conf, type_changes.new_type.unqualified_name, dir)
    @title = _("%d API Change Overview") % type_changes.new_type.unqualified_name
    @type_changes = type_changes
  end

  def generate_body_content
    html_h1(@title)

    summary_table(@type_changes.added_fields, _("Added Fields")) do |as_field|
      pcdata(as_field.name)
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

    summary_table(@type_changes.added_methods, _("Added Methods")) do |as_method|
      pcdata(as_method.name)
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
      html_code(field_changes.visibility_change.old_vis)
      pcdata(_(" to "))
      html_code(field_changes.visibility_change.new_vis)
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

  def navigation
    html_ul("class"=>"main_nav") do
      # TODO
    end
  end
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

  list
end

def generate_diffs(conf, api_changes)
  list = make_diff_pages(conf, api_changes)
  create_all_pages(conf, list)
end


# vim:softtabstop=2:shiftwidth=2
