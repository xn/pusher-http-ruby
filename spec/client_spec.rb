require 'spec_helper'

require 'em-http'

describe Pusher do
  # The behaviour should be the same when using the Client object, or the
  # 'global' client delegated through the Pusher class
  [lambda { Pusher }, lambda { Pusher::Client.new }].each do |client_gen|
    before :each do
      @client = client_gen.call
    end

    describe 'default configuration' do
      it 'should be preconfigured for api host' do
        expect(@client.host).to eq('api.pusherapp.com')
      end

      it 'should be preconfigured for port 80' do
        expect(@client.port).to eq(80)
      end

      it 'should use standard logger if no other logger if defined' do
        Pusher.logger.debug('foo')
        expect(Pusher.logger).to be_kind_of(Logger)
      end
    end

    describe 'logging configuration' do
      it "can be configured to use any logger" do
        logger = double("ALogger")
        expect(logger).to receive(:debug).with('foo')
        Pusher.logger = logger
        Pusher.logger.debug('foo')
        Pusher.logger = nil
      end
    end

    describe "configuration using url" do
      it "should be possible to configure everything by setting the url" do
        @client.url = "test://somekey:somesecret@api.staging.pusherapp.com:8080/apps/87"

        expect(@client.scheme).to eq('test')
        expect(@client.host).to eq('api.staging.pusherapp.com')
        expect(@client.port).to eq(8080)
        expect(@client.key).to eq('somekey')
        expect(@client.secret).to eq('somesecret')
        expect(@client.app_id).to eq('87')
      end

      it "should override scheme and port when setting encrypted=true after url" do
        @client.url = "http://somekey:somesecret@api.staging.pusherapp.com:8080/apps/87"
        @client.encrypted = true

        expect(@client.scheme).to eq('https')
        expect(@client.port).to eq(443)
      end

      it "should fail on bad urls" do
        expect { @client.url = "gopher/somekey:somesecret@://api.staging.pusherapp.co://m:8080\apps\87" }.to raise_error(URI::InvalidURIError)
      end
    end

    describe 'configuring a http proxy' do
      it "should be possible to configure everything by setting the http_proxy" do
        @client.http_proxy = 'http://someuser:somepassword@proxy.host.com:8080'

        expect(@client.proxy).to eq({:scheme => 'http', :host => 'proxy.host.com', :port => 8080, :user => 'someuser', :password => 'somepassword'})
      end
    end

    describe 'when configured' do
      before :each do
        @client.app_id = '20'
        @client.key    = '12345678900000001'
        @client.secret = '12345678900000001'
      end

      describe '#[]' do
        before do
          @channel = @client['test_channel']
        end

        it 'should return a channel' do
          expect(@channel).to be_kind_of(Pusher::Channel)
        end

        %w{app_id key secret}.each do |config|
          it "should raise exception if #{config} not configured" do
            @client.send("#{config}=", nil)
            expect {
              @client['test_channel']
            }.to raise_error(Pusher::ConfigurationError)
          end
        end
      end

      describe '#channels' do
        it "should call the correct URL and symbolise response correctly" do
          api_path = %r{/apps/20/channels}
          stub_request(:get, api_path).to_return({
            :status => 200,
            :body => MultiJson.encode('channels' => {
              "channel1" => {},
              "channel2" => {}
            })
          })
          expect(@client.channels).to eq({
            :channels => {
              "channel1" => {},
              "channel2" => {}
            }
          })
        end
      end

      describe '#channel_info' do
        it "should call correct URL and symbolise response" do
          api_path = %r{/apps/20/channels/mychannel}
          stub_request(:get, api_path).to_return({
            :status => 200,
            :body => MultiJson.encode({
              'occupied' => false,
            })
          })
          expect(@client.channel_info('mychannel')).to eq({
            :occupied => false,
          })
        end
      end

      describe '#trigger' do
        before :each do
          @api_path = %r{/apps/20/events}
          stub_request(:post, @api_path).to_return({
            :status => 200,
            :body => MultiJson.encode({})
          })
        end

        it "should call correct URL" do
          expect(@client.trigger(['mychannel'], 'event', {'some' => 'data'})).
            to eq({})
        end

        it "should not allow too many channels" do
          expect {
            @client.trigger((0..11).map{|i| 'mychannel#{i}'},
              'event', {'some' => 'data'}, {
                :socket_id => "12.34"
              })}.to raise_error(Pusher::Error)
        end

        it "should pass any parameters in the body of the request" do
          @client.trigger(['mychannel', 'c2'], 'event', {'some' => 'data'}, {
            :socket_id => "12.34"
          })
          expect(WebMock).to have_requested(:post, @api_path).with { |req|
            parsed = MultiJson.decode(req.body)
            expect(parsed["name"]).to eq('event')
            expect(parsed["channels"]).to eq(["mychannel", "c2"])
            expect(parsed["socket_id"]).to eq('12.34')
          }
        end

        it "should convert non string data to JSON before posting" do
          @client.trigger(['mychannel'], 'event', {'some' => 'data'})
          expect(WebMock).to have_requested(:post, @api_path).with { |req|
            expect(MultiJson.decode(req.body)["data"]).to eq('{"some":"data"}')
          }
        end

        it "should accept a single channel as well as an array" do
          @client.trigger('mychannel', 'event', {'some' => 'data'})
          expect(WebMock).to have_requested(:post, @api_path).with { |req|
            expect(MultiJson.decode(req.body)["channels"]).to eq(['mychannel'])
          }
        end
      end

      describe '#trigger_async' do
        before :each do
          @api_path = %r{/apps/20/events}
          stub_request(:post, @api_path).to_return({
            :status => 200,
            :body => MultiJson.encode({})
          })
        end

        it "should call correct URL" do
          EM.run {
            @client.trigger_async('mychannel', 'event', {'some' => 'data'}).callback { |r|
              expect(r).to eq({})
              EM.stop
            }
          }
        end

        it "should pass any parameters in the body of the request" do
          EM.run {
            @client.trigger_async('mychannel', 'event', {'some' => 'data'}, {
              :socket_id => "12.34"
            }).callback {
              expect(WebMock).to have_requested(:post, @api_path).with { |req|
                expect(MultiJson.decode(req.body)["socket_id"]).to eq('12.34')
              }
              EM.stop
            }
          }
        end

        it "should convert non string data to JSON before posting" do
          EM.run {
            @client.trigger_async('mychannel', 'event', {'some' => 'data'}).callback {
              expect(WebMock).to have_requested(:post, @api_path).with { |req|
                expect(MultiJson.decode(req.body)["data"]).to eq('{"some":"data"}')
              }
              EM.stop
            }
          }
        end
      end

      [:get, :post].each do |verb|
        describe "##{verb}" do
          before :each do
            @url_regexp = %r{api.pusherapp.com}
            stub_request(verb, @url_regexp).
              to_return(:status => 200, :body => "{}")
          end

          let(:call_api) { @client.send(verb, '/path') }

          it "should use http by default" do
            call_api
            expect(WebMock).to have_requested(verb, %r{http://api.pusherapp.com/apps/20/path})
          end

          it "should use https if configured" do
            @client.encrypted = true
            call_api
            expect(WebMock).to have_requested(verb, %r{https://api.pusherapp.com})
          end

          it "should format the respose hash with symbols at first level" do
            stub_request(verb, @url_regexp).to_return({
              :status => 200,
              :body => MultiJson.encode({'something' => {'a' => 'hash'}})
            })
            expect(call_api).to eq({
              :something => {'a' => 'hash'}
            })
          end

          it "should catch all http exceptions and raise a Pusher::HTTPError wrapping the original error" do
            stub_request(verb, @url_regexp).to_raise(HTTPClient::TimeoutError)

            error = nil
            begin
              call_api
            rescue => e
              error = e
            end

            expect(error.class).to eq(Pusher::HTTPError)
            expect(error).to be_kind_of(Pusher::Error)
            expect(error.message).to eq('Exception from WebMock (HTTPClient::TimeoutError)')
            expect(error.original_error.class).to eq(HTTPClient::TimeoutError)
          end

          it "should raise Pusher::Error if call returns 400" do
            stub_request(verb, @url_regexp).to_return({:status => 400})
            expect { call_api }.to raise_error(Pusher::Error)
          end

          it "should raise AuthenticationError if pusher returns 401" do
            stub_request(verb, @url_regexp).to_return({:status => 401})
            expect { call_api }.to raise_error(Pusher::AuthenticationError)
          end

          it "should raise Pusher::Error if pusher returns 404" do
            stub_request(verb, @url_regexp).to_return({:status => 404})
            expect { call_api }.to raise_error(Pusher::Error, '404 Not found (/apps/20/path)')
          end

          it "should raise Pusher::Error if pusher returns 407" do
            stub_request(verb, @url_regexp).to_return({:status => 407})
            expect { call_api }.to raise_error(Pusher::Error, 'Proxy Authentication Required')
          end

          it "should raise Pusher::Error if pusher returns 500" do
            stub_request(verb, @url_regexp).to_return({:status => 500, :body => "some error"})
            expect { call_api }.to raise_error(Pusher::Error, 'Unknown error (status code 500): some error')
          end
        end
      end

      describe "async calling without eventmachine" do
        [[:get, :get_async], [:post, :post_async]].each do |verb, method|
          describe "##{method}" do
            before :each do
              @url_regexp = %r{api.pusherapp.com}
              stub_request(verb, @url_regexp).
                to_return(:status => 200, :body => "{}")
            end

            let(:call_api) {
              @client.send(method, '/path').tap { |c|
                # Allow the async thread (inside httpclient) to run
                while !c.finished?
                  sleep 0.01
                end
              }
            }

            it "should use http by default" do
              call_api
              expect(WebMock).to have_requested(verb, %r{http://api.pusherapp.com/apps/20/path})
            end

            it "should use https if configured" do
              @client.encrypted = true
              call_api
              expect(WebMock).to have_requested(verb, %r{https://api.pusherapp.com})
            end

            # Note that the raw httpclient connection object is returned and
            # the response isn't handled (by handle_response) in the normal way.
            it "should return a httpclient connection object" do
              connection = call_api
              expect(connection.finished?).to be_truthy
              response = connection.pop
              expect(response.status).to eq(200)
              expect(response.body.read).to eq("{}")
            end
          end
        end
      end

      describe "async calling with eventmachine" do
        [[:get, :get_async], [:post, :post_async]].each do |verb, method|
          describe "##{method}" do
            before :each do
              @url_regexp = %r{api.pusherapp.com}
              stub_request(verb, @url_regexp).
                to_return(:status => 200, :body => "{}")
            end

            let(:call_api) { @client.send(method, '/path') }

            it "should use http by default" do
              EM.run {
                call_api.callback {
                  expect(WebMock).to have_requested(verb, %r{http://api.pusherapp.com/apps/20/path})
                  EM.stop
                }
              }
            end

            it "should use https if configured" do
              EM.run {
                @client.encrypted = true
                call_api.callback {
                  expect(WebMock).to have_requested(verb, %r{https://api.pusherapp.com})
                  EM.stop
                }
              }
            end

            it "should format the respose hash with symbols at first level" do
              EM.run {
                stub_request(verb, @url_regexp).to_return({
                  :status => 200,
                  :body => MultiJson.encode({'something' => {'a' => 'hash'}})
                })
                call_api.callback { |response|
                  expect(response).to eq({
                    :something => {'a' => 'hash'}
                  })
                  EM.stop
                }
              }
            end

            it "should errback with Pusher::Error on unsuccessful response" do
              EM.run {
                stub_request(verb, @url_regexp).to_return({:status => 400})

                call_api.errback { |e|
                  expect(e.class).to eq(Pusher::Error)
                  EM.stop
                }.callback {
                  fail
                }
              }
            end
          end
        end
      end
    end
  end
end
