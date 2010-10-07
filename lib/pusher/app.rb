module Pusher
  
  class App
    
    attr_accessor :host, :port, :key, :secret, :app_id
    
    def initialize(opts = {})
      @host = opts[:host]
      @port = opts[:port]
      @app_id = opts[:app_id]
      @key = opts[:key]
      @secret = opts[:secret]
    end
    
    def [](channel_name)
      raise ConfigurationError, 'Missing configuration: please check that Pusher.url is configured' unless configured?
      @channels ||= {}
      @channels[channel_name.to_s] ||= Channel.new(self, channel_name)
    end
    
    def authentication_token
      Signature::Token.new(@key, @secret)
    end
    
    def url
      @url ||= URI::HTTP.build({
        :host => self.host,
        :port => self.port,
        :path => "/apps/#{self.app_id}"
      })
    end
    
    protected
    
    def configured?
      host && port && key && secret && app_id
    end
  end
  
end