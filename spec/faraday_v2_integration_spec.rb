require 'spec_helper'

RSpec.describe 'Faraday 2.x Integration' do
  let(:client_id) { '22942C' }
  let(:client_secret) { 'secret' }
  let(:token) { 'test_token' }
  let(:user_id) { '26FWFL' }
  let(:unit_system) { 'en_US' }
  let(:client) { FitgemOauth2::Client.new(client_id: client_id, client_secret: client_secret, token: token, user_id: user_id, unit_system: unit_system) }

  describe 'HTTP request handling with Faraday 2.x' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/user/-/profile.json') { [200, {'Content-Type' => 'application/json'}, '{"user": {"encodedId": "test123"}}'] }
            stub.post('/1/test') { [200, {'Content-Type' => 'application/json'}, '{"success": true}'] }
            stub.delete('/1/test') { [204, {}, ''] }
          end
        end
      )
    end

    it 'handles GET requests with Faraday 2.x' do
      result = client.get_call('user/-/profile.json')
      expect(result).to have_key('user')
      expect(result['user']['encodedId']).to eq('test123')
    end

    it 'handles POST requests with Faraday 2.x' do
      result = client.post_call('test', {data: 'test'})
      expect(result).to have_key('success')
      expect(result['success']).to be true
    end

    it 'handles DELETE requests with Faraday 2.x' do
      result = client.delete_call('test')
      expect(result).to be_nil # 204 response returns nil
    end
  end

  describe 'Faraday 2.x adapter configuration' do
    it 'uses default adapter when none specified' do
      connection = client.send(:connection)
      expect(connection.builder).to be_a(Faraday::RackBuilder)
      expect(connection.url_prefix.to_s).to eq('https://api.fitbit.com/')
    end

    it 'has proper request middleware configured' do
      connection = client.send(:connection)
      middleware_classes = connection.builder.handlers.map(&:name)
      expect(middleware_classes).to include('Faraday::Request::UrlEncoded')
    end
  end

  describe 'Faraday 2.x connection management' do
    it 'maintains connection state across requests' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/state-test') { [200, {'Content-Type' => 'application/json'}, '{"state": "maintained"}'] }
          end
        end
      )

      result1 = client.get_call('state-test')
      expect(result1['state']).to eq('maintained')

      result2 = client.get_call('state-test')
      expect(result2['state']).to eq('maintained')
    end
  end

  describe 'Faraday 2.x response handling' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/json') { [200, {'Content-Type' => 'application/json'}, '{"key": "value"}'] }
            stub.get('/1/empty') { [204, {}, ''] }
          end
        end
      )
    end

    it 'handles JSON responses' do
      json_response = client.get_call('json')
      expect(json_response).to be_a(Hash)
      expect(json_response['key']).to eq('value')
    end

    it 'handles empty responses' do
      empty_response = client.get_call('empty')
      expect(empty_response).to be_nil # 204 response returns nil
    end
  end

  describe 'Faraday 2.x error response handling' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/server-error') { [500, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Internal server error"}]}'] }
          end
        end
      )
    end

    it 'handles HTTP 500 server errors' do
      expect {
        client.get_call('server-error')
      }.to raise_error(FitgemOauth2::ServerError) # 500 errors should raise ServerError
    end
  end

  describe 'Faraday 2.x middleware compatibility' do
    it 'works with standard middleware stack' do
      connection = client.send(:connection)

      # Should have URL encoding middleware
      middleware_classes = connection.builder.handlers.map(&:name)
      expect(middleware_classes).to include('Faraday::Request::UrlEncoded')

      # Should have proper connection configuration
      expect(connection).to be_a(Faraday::Connection)
    end

    it 'maintains compatibility with existing response format' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/compatibility') { [200, {'Content-Type' => 'application/json'}, '{"compatible": true}'] }
          end
        end
      )

      result = client.get_call('compatibility')
      expect(result).to have_key('compatible')
      expect(result['compatible']).to be true
    end
  end
end