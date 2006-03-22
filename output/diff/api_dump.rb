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


require 'output/diff/api_serializer'
require 'output/diff/api_deserializer'


# Generates an XML dump of the data in the given GlobalTypeAggregator to
# a file with a name based on settings from the given config structure
def generate_api_dump(conf, type_aggregator)
  File.open(api_dump_name(conf.api_name, conf.api_version), "w") do |io|
    ser = APISerializer.new(io, conf.api_name, conf.api_version)
    ser.serialize_api(type_aggregator)
  end
end

# Given an the name and version of an API, work out what filename the API's
# description should be stored in by downcasing, replacing any non-alphanumeric
# characters in both strings with underscores, joining the name to the version
# with a minushyphen ('-') and appending '.xml'.
#
#   api_dump_name('My Cool API!', "1.1a")  # => "my_cool_api_-1_1a.xml"
#
def api_dump_name(api_name, api_version)
  api_name = api_name.gsub(/[^a-zA-Z0-9]/, "_").downcase
  api_version = api_version.gsub(/[^a-zA-Z0-9]/, "_").downcase
  "#{api_name}-#{api_version}.xml"
end

def load_api_dump(filename)
  File.open(filename) do |io|
    deser = APIDeserializer.new(io)
    return deser.deserialize_api
  end
end

# vim:sw=2:sts=2
