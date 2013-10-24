# Monkey-copied from openssl cookbook
# because for some reason the recipes in this cookbook can't see that one
# Yes, the metadata is configured properly.

require 'openssl'

module SecurePassword
  def self.secure_password(length = 20)
    pw = String.new

    while pw.length < length
      pw << ::OpenSSL::Random.random_bytes(1).gsub(/\W/, '')
    end
    pw
  end
end
