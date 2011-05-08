# vim:fileencoding=utf-8

require 'dbee/job/encode/ipad'
require 'dbee/job/download'
require 'dbee/job/generate_metadata'
require 'dbee/job/upload/s3'
require 'dbee/job/notification'

Encoding.default_internal = "UTF-8" if defined? Encoding
Encoding.default_external = "UTF-8" if defined? Encoding

module DBEE
  module Job; end
end
