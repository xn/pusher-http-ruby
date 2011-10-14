require 'spec_helper'

class WebHookRequest
  attr_reader :headers, :body

  def initialize(key, hmac, body)
    @headers = {}
    @headers["X-Pusher-AppKey"] = key
    @headers["X-Pusher-HMAC-SHA256"] = hmac
    @body = StringIO.new(body)
  end
end

describe "Hooker" do
  before do
    Pusher.app_id = '20'
    Pusher.key    = '12345678900000001'
    Pusher.secret = '12345678900000002'
    Pusher.host = 'api.pusherapp.com'
    Pusher.port = 80
    Pusher.encrypted = false

    @body_str = "{\"event_type\":\"channel_existence\",\"data\":{\"event\":\"occupied\",\"channel\":\"test-aqss22\"}}"
  end

  after do
    Pusher.app_id = nil
    Pusher.key = nil
    Pusher.secret = nil
  end

  describe 'authentic?' do
    it 'should raise an exception if keys on request and Pusher.key do not match' do
      request = WebHookRequest.new("another_key", "whatever", "whatever")
      lambda {
        Pusher::Hooker.authentic?(request)
      }.should raise_error(Pusher::AuthenticationError)
    end

    it 'should return true for a valid request' do
      hmac = HMAC::SHA256.hexdigest(Pusher.secret, @body_str)
      request = WebHookRequest.new(Pusher.key, hmac, @body_str)

      Pusher::Hooker.authentic?(request).should == true
    end

    it 'should return false for an invalid request' do
      hmac = "wrong"
      request = WebHookRequest.new(Pusher.key, hmac, @body_str)

      Pusher::Hooker.authentic?(request).should == false
    end

    it 'should rewind the body stringio after extraction' do
      hmac = HMAC::SHA256.hexdigest(Pusher.secret, @body_str)
      request = WebHookRequest.new(Pusher.key, hmac, @body_str)

      Pusher::Hooker.authentic?(request)
      request.body.read.should == @body_str
    end
  end

  describe 'extract_data' do
    it 'should raise an exception if keys on request and Pusher.key do not match' do
      request = WebHookRequest.new("another_key", "whatever", "whatever")
      lambda {
        Pusher::Hooker.extract_data(request)
      }.should raise_error(Pusher::AuthenticationError)
    end

    it 'should raise an exception if signature is invalid' do
      hmac = "wrong"
      request = WebHookRequest.new(Pusher.key, hmac, @body_str)
      lambda {
        Pusher::Hooker.extract_data(request)
      }.should raise_error(Pusher::AuthenticationError)
    end

    it 'should return hash with right data for a valid request' do
      hmac = HMAC::SHA256.hexdigest(Pusher.secret, @body_str)
      request = WebHookRequest.new(Pusher.key, hmac, @body_str)

      data = Pusher::Hooker.extract_data(request)
      data["event_type"].should == "channel_existence"
      data["data"]["event"].should == "occupied"
      data["data"]["channel"].should == "test-aqss22"
    end

    it 'should rewind the body stringio after extraction' do
      hmac = HMAC::SHA256.hexdigest(Pusher.secret, @body_str)
      request = WebHookRequest.new(Pusher.key, hmac, @body_str)

      Pusher::Hooker.extract_data(request)
      request.body.read.should == @body_str
    end
  end
end
