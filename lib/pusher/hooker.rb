require 'hmac-sha2'
require 'multi_json'

module Pusher
  class Hooker

    def self.authentic?(request)
      request_key = request.headers["X-Pusher-AppKey"]
      raise AuthenticationError, "Key stored in Pusher.key does not match one sent with web hook" unless Pusher.key == request_key

      secret = Pusher.secret
      request_hmac = request.headers["X-Pusher-HMAC-SHA256"]
      body = request.body.read
      request.body.rewind

      return request_hmac == HMAC::SHA256.hexdigest(secret, body)
    end

    def self.extract_data(request)
      body = request.body.read
      request.body.rewind

      raise AuthenticationError, "Request signature invalid." unless self.authentic?(request)

      return MultiJson.decode(body)
    end
  end
end
