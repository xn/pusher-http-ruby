autoload 'Logger', 'logger'
require 'uri'
require 'pusher/app'

module Pusher
  class Error < RuntimeError; end
  class AuthenticationError < Error; end
  class ConfigurationError < Error; end
  
  class << self
    attr_writer :logger
    
    # Instantiate an App with custom config
    def app(opts)
      opts[:host] ||= self.host
      opts[:port] ||= self.port
      Pusher::App.new(opts)
    end
    
    [:host=, :port=, :app_id=, :key=, :secret=, :host=].each do |m|
      define_method(m) do |value|
        default_app.send(m, value)
      end
    end
    
    [:host, :port, :app_id, :key, :secret, :host].each do |m|
      define_method(m) do
        default_app.send(m)
      end
    end
    
    def logger
      @logger ||= begin
        log = Logger.new(STDOUT)
        log.level = Logger::INFO
        log
      end
    end
    
    def default_app
      @default_app ||= Pusher::App.new
    end

    def [](channel_name)
      default_app[channel_name]
    end

    # Builds a connection url for Pusherapp
    def url
      default_app.url
    end

    # Allows configuration from a url
    def url=(url)
      uri = URI.parse(url)
      self.app_id = uri.path.split('/').last
      self.key    = uri.user
      self.secret = uri.password
      self.host   = uri.host
      self.port   = uri.port
    end

    private

  end

  self.host = 'api.pusherapp.com'
  self.port = 80
    
  if ENV['PUSHER_URL']
    self.url = ENV['PUSHER_URL']
  end
  
  
end

require 'pusher/json'
require 'pusher/channel'
require 'pusher/request'
