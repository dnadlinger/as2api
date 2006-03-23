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

# utilities pertaining to the use of JavaDoc in XLIFF


module XliffIds

  def self.id_prefix_for_type(astype)
    "class-#{to_id(astype.qualified_name)}"
  end

  def self.id_prefix_for_method(asmethod)
    "#{id_prefix_for_type(asmethod.containing_type)}-method-#{to_id(asmethod.name)}"
  end

  def self.id_prefix_for_field(asfield)
    "#{id_prefix_for_type(asfield.containing_type)}-field-#{to_id(asfield.name)}"
  end

  def self.id_prefix_for_parameter(asmethod, param_name)
    "#{id_prefix_for_method(asmethod)}-param-#{to_id(param_name)}"
  end

  def self.id_for_type_description(astype)
    "#{id_prefix_for_type(astype)}-description"
  end

  def self.id_for_method_description(asmethod)
    "#{id_prefix_for_method(asmethod)}-description"
  end

  def self.id_for_method_return(asmethod)
    "#{id_prefix_for_method(asmethod)}-return"
  end

  def self.id_for_field_description(asfield)
    "#{id_prefix_for_field(asfield)}-description"
  end

  def self.id_for_parameter_description(asmethod, param_name)
    "#{id_prefix_for_parameter(asmethod, param_name)}-description"
  end

  def self.id_prefix_for_throws(asmethod, exception_type)
    "#{id_prefix_for_method(asmethod)}-throws-#{to_id(exception_type.qualified_name)}"
  end

  def self.id_for_throws_description(asmethod, exception_type)
    "#{id_prefix_for_throws(asmethod, exception_type)}-description"
  end

  def self.id_for_type_see(astype, index)
    "#{id_prefix_for_type(astype)}-see-#{index}"
  end

  def self.id_for_method_see(asmethod, index)
    "#{id_prefix_for_method(asmethod)}-see-#{index}"
  end

  def self.to_id(text)
    text.gsub(/[^-.a-zA-Z0-9]/) do |match|
      "_" + match[0].to_s(16)
    end
  end

  def self.from_id(text)
    text.gsub(/_([0-9a-fA-F]{2})/) do |match|
      $1.to_s.to_i(16).chr
    end
  end
end

# vim:sw=2:sts=2
