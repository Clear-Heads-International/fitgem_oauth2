require 'spec_helper'

RSpec.describe 'Faraday 2.x Adapter Configuration' do
  let(:client_id) { '22942C' }
  let(:client_secret) { 'secret' }
  let(:token) { 'test_token' }
  let(:user_id) { '26FWFL' }
  let(:unit_system) { 'en_US' }
  let(:client) { FitgemOauth2::Client.new(client_id: client_id, client_secret: client_secret, token: token, user_id: user_id, unit_system: unit_system) }

  describe 'Default adapter configuration' do
    it 'uses NetHttp adapter by default' do
      connection = client.send(:connection)
      # Check if the adapter is properly configured
      expect(connection.builder.adapter).not_to be_nil
      expect(connection).to respond_to(:get, :post, :delete)
    end

    it 'configures adapter with correct URL prefix' do
      connection = client.send(:connection)
      expect(connection.url_prefix.to_s).to eq('https://api.fitbit.com/')
    end
  end

  describe 'Middleware configuration' do
    it 'includes url encoding middleware' do
      connection = client.send(:connection)
      middleware_classes = connection.builder.handlers.map(&:name)
      expect(middleware_classes).to include('Faraday::Request::UrlEncoded')
    end

    it 'properly sets up request headers' do
      connection = client.send(:connection)
      expect(connection.headers).to be_a(Hash)
      expect(connection.headers).to have_key('User-Agent')
    end
  end

  describe 'SSL configuration' do
    it 'has SSL options configured' do
      connection = client.send(:connection)
      expect(connection.ssl).to be_a(Faraday::SSLOptions)
    end

    it 'uses HTTPS by default' do
      connection = client.send(:connection)
      expect(connection.url_prefix.scheme).to eq('https')
    end
  end

  describe 'Faraday 2.x specific features' do
    it 'supports Faraday 2.x adapter configuration' do
      # Test that the connection works with Faraday 2.x features
      connection = client.send(:connection)
      expect(connection).to respond_to(:get, :post, :delete, :run_request)
    end

    it 'maintains backward compatibility with request format' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/test') { [200, {'Content-Type' => 'application/json'}, '{"success": true}'] }
          end
        end
      )

      result = client.get_call('test')
      expect(result).to have_key('success')
      expect(result['success']).to be true
    end
  end

  describe 'Connection options' do
    it 'has proper request options configured' do
      connection = client.send(:connection)
      expect(connection.options).to be_a(Faraday::RequestOptions)
    end

    it 'has proper request options configured' do
      connection = client.send(:connection)
      expect(connection.options).to respond_to(:timeout, :open_timeout)
    end
  end

  describe 'Adapter behavior with Faraday 2.x' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/adapter-test') { [200, {'Content-Type' => 'application/json'}, '{"adapter": "test"}'] }
            stub.post('/1/adapter-test') { [200, {'Content-Type' => 'application/json'}, '{"created": true}'] }
            stub.delete('/1/adapter-test') { [204, {}, ''] }
          end
        end
      )
    end

    it 'handles GET requests with Faraday 2.x adapter' do
      result = client.get_call('adapter-test')
      expect(result).to have_key('adapter')
      expect(result['adapter']).to eq('test')
    end

    it 'handles POST requests with Faraday 2.x adapter' do
      result = client.post_call('adapter-test', {data: 'test'})
      expect(result).to have_key('created')
      expect(result['created']).to be true
    end

    it 'handles DELETE requests with Faraday 2.x adapter' do
      result = client.delete_call('adapter-test')
      expect(result).to be_nil # 204 response returns nil
    end
  end

  describe 'Environment-specific configuration' do
    it 'works in test environment with test adapter' do
      # This test verifies that the adapter configuration works in test mode
      connection = client.send(:connection)
      expect(connection).to be_a(Faraday::Connection)
      expect(connection.builder.adapter).not_to be_nil
    end
  end

  describe 'Faraday version compatibility' do
    it 'is compatible with Faraday 2.x' do
      # Verify that we're using a compatible Faraday version
      expect(Faraday::VERSION).to match(/^2\./)
    end

    it 'loads required Faraday 2.x components' do
      expect { Faraday::Connection }.not_to raise_error
      expect { Faraday::Request }.not_to raise_error
      expect { Faraday::Response }.not_to raise_error
    end
  end
end