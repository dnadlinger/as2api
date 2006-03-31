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


class APIDiff
  def diff(old, new)
    added_packages, removed_packages, oldpkg_to_newpkg = diff_lists(old.packages, new.packages) {|old,new| old.name==new.name}

    modified_packages = diff_map(oldpkg_to_newpkg, :diff_package)

    if added_packages.empty? && removed_packages.empty? && modified_packages.empty?
      nil
    else
      APIChanges.new(added_packages, removed_packages, modified_packages)
    end
  end

  private

  def diff_lists(oldlist, newlist)
    removed = []
    matching = {}

    oldlist.each do |oldval|
      newval = newlist.detect {|a| yield oldval,a}
      if newval
	matching[oldval] = newval
      else
	removed << oldval
      end
    end

    added = newlist - matching.values

    [added, removed, matching]
  end

  def find_package(packages, name)
    packages.detect {|pkg| pkg.name == name}
  end

  def diff_map(old_to_new, diff_method_sym)
    result = []
    old_to_new.each do |oldval, newval|
      change = send(diff_method_sym, oldval, newval)
      result << change if change
    end
    result
  end

  def diff_package(oldpkg, newpkg)
    added_types, removed_types, old_to_new = diff_lists(oldpkg.types, newpkg.types) {|old,new| old.unqualified_name==new.unqualified_name}
    
    modified_types = diff_map(old_to_new, :diff_type)
    if added_types.empty? && removed_types.empty? && modified_types.empty?
      nil
    else
      PackageChanges.new(newpkg.name, added_types, removed_types, modified_types)
    end
  end

  def diff_type(old_type, new_type)
    # TODO: handle class>interface, interface>class changes
    if old_type.is_a?(ASClass) && new_type.is_a?(ASClass)
      added_fields, removed_fields, old_to_new_fields = diff_lists(old_type.fields, new_type.fields) {|old,new| old.name==new.name}
      modified_fields = diff_map(old_to_new_fields, :diff_field)
    else
      added_fields = removed_fields = modified_fields = nil
    end

    added_methods, removed_methods, old_to_new_methods = diff_lists(old_type.methods, new_type.methods) {|old,new| old.name==new.name}
    modified_methods = diff_map(old_to_new_methods, :diff_method)
    
    if added_methods.empty? && removed_methods.empty? && (new_type.is_a?(ASInterface) || new_type.is_a?(ASClass) && modified_methods.empty? && added_fields.empty? && removed_fields.empty? && modified_fields.empty?)
      nil
    else
      TypeChanges.new(new_type, added_methods, removed_methods, modified_methods, added_fields, removed_fields, modified_fields)
    end
  end

  def diff_field(old_field, new_field)
    visibility_change, static_change = diff_access(old_field.access, new_field.access)
    type_change = diff_typesig(old_field.field_type, new_field.field_type)
    readwrite_change = diff_field_readwrite(old_field, new_field)

    if visibility_change || static_change || type_change || readwrite_change
      FieldChange.new(new_field.name, visibility_change, static_change, type_change, readwrite_change)
    else
      nil
    end
  end

  def diff_method(old_method, new_method)
    visibility_change, static_change = diff_access(old_method.access, new_method.access)
    type_change = diff_typesig(old_method.return_type, new_method.return_type)
    args_change = diff_args(old_method.arguments, new_method.arguments)
    if visibility_change || static_change || type_change || args_change
      MethodChange.new(new_method.name, visibility_change, static_change, type_change, args_change)
    else
      nil
    end
  end

  def diff_access(old_access, new_access)
    visibility_change = diff_visibility(old_access.visibility, new_access.visibility)
    static_change = diff_static(old_access.static?, new_access.static?)
    [visibility_change, static_change]
  end

  def diff_visibility(old_visibility, new_visibility)
    if old_visibility != new_visibility
      VisibilityChange.new(old_visibility, new_visibility)
    else
      nil
    end
  end

  def diff_static(old_flag, new_flag)
    if old_flag != new_flag
      StaticChange.new(old_flag, new_flag)
    else
      nil
    end
  end

  def diff_field_readwrite(old_field, new_field)
    # TODO: smells like an enumeration (RO, WO, RW) is needed,
    if old_field.read? != new_field.read? || old_field.write? != new_field.write?
      ReadWriteChange.new(old_field.read?, new_field.read?, old_field.write?, new_field.write?)
    else
      nil
    end
  end

  def diff_typesig(old_type, new_type)
    if old_type.nil?
      old_type_name = nil
    else
      old_type_name = old_type.resolved? ? old_type.resolved_type.qualified_name : old_type.local_name
    end
    if new_type.nil?
      new_type_name = nil
    else
      new_type_name = new_type.resolved? ? new_type.resolved_type.qualified_name : new_type.local_name
    end
    if old_type_name != new_type_name
      TypeSigChange.new(old_type_name, new_type_name)
    end
  end

  def args_differ?(old_args, new_args)
    return true if old_args.length != new_args.length

    old_args.each_with_index do |arg, i|
      return true unless arg.name == new_args[i].name && arg_type_name(arg.arg_type) == arg_type_name(new_args[i].arg_type)
    end

    false
  end

  def arg_type_name(arg_type)
    return nil if arg_type.nil?
    arg_type.resolved? ? arg_type.resolved_type.qualified_name : arg_type.local_name
  end

  def diff_args(old_args, new_args)
    if args_differ?(old_args, new_args)
      ArgumentChange.new(old_args, new_args)
    else
      nil
    end
  end
end


class APIChanges
  def initialize(added_packages, removed_packages, modified_packages)
    @added_packages = added_packages
    @removed_packages = removed_packages
    @modified_packages = modified_packages
  end

  attr_accessor :added_packages, :removed_packages, :modified_packages, :api_name, :api_old_ver, :api_new_ver
end


class PackageChanges
  def initialize(name, added_types, removed_types, modified_types)
    @name = name
    @added_types = added_types
    @removed_types = removed_types
    @modified_types = modified_types
  end

  attr_accessor :name, :added_types, :removed_types, :modified_types

  def added_types?; !@added_types.empty?; end
  def removed_types?; !@removed_types.empty?; end
  def modified_types?; !@modified_types.empty?; end

  def default?
    name.nil? || name == ""
  end
end

class TypeChanges
  def initialize(new_type, added_methods, removed_methods, modified_methods, added_fields, removed_fields, modified_fields)
    @new_type = new_type
    @added_methods = added_methods
    @removed_methods = removed_methods
    @modified_methods = modified_methods
    @added_fields = added_fields
    @removed_fields = removed_fields
    @modified_fields = modified_fields
  end

  def added_methods?; @added_methods && !@added_methods.empty?; end
  def modified_methods?; @modified_methods && !@modified_methods.empty?; end
  def removed_methods?; @removed_methods && !@removed_methods.empty?; end
  def added_fields?; @added_fields && !@added_fields.empty?; end
  def removed_fields?; @removed_fields && !@removed_fields.empty?; end
  def modified_fields?; @modified_fields && !@modified_fields.empty?; end

  attr_accessor :new_type, :added_methods, :removed_methods, :modified_methods, :added_fields, :removed_fields, :modified_fields
end

class VisibilityChange
  def initialize(old_vis, new_vis)
    @old_vis = old_vis
    @new_vis = new_vis
  end

  attr_accessor :old_vis, :new_vis
end


class FieldChange
  def initialize(name, visibility_change, static_change, type_change, readwrite_change)
    @name = name
    @visibility_change = visibility_change
    @static_change = static_change
    @type_change = type_change
    @readwrite_change = readwrite_change
  end

  attr_accessor :name, :visibility_change, :static_change, :type_change, :readwrite_change
end

class MethodChange
  def initialize(name, visibility_change, static_change, type_change, args_change)
    @name = name
    @visibility_change = visibility_change
    @static_change = static_change
    @type_change = type_change
    @args_change = args_change
  end

  attr_accessor :name, :visibility_change, :static_change, :type_change, :args_change
end

class StaticChange
  def initialize(old_flag, new_flag)
    @old_flag = old_flag
    @new_flag = new_flag
  end

  attr_accessor :old_flag, :new_flag
end


class ReadWriteChange
  def initialize(old_read, new_read, old_write, new_write)
    @old_read = old_read
    @new_read = new_read
    @old_write = old_write
    @new_write = new_write
  end

  attr_accessor :old_read, :new_read, :old_write, :new_write
end

class TypeSigChange
  # TODO: pass the ASTypes instead
  def initialize(old_type_name, new_type_name)
    @old_type_name = old_type_name
    @new_type_name = new_type_name
  end

  attr_accessor :old_type_name, :new_type_name
end

ArgumentChange = Struct.new("ArgumentChange", :old_args, :new_args)

# vim:shiftwidth=2:softtabstop=2
