require 'spec_helper'

RSpec.describe 'Middleware Compatibility with Faraday 2.x' do
  let(:client_id) { '22942C' }
  let(:client_secret) { 'secret' }
  let(:token) { 'test_token' }
  let(:user_id) { '26FWFL' }
  let(:unit_system) { 'en_US' }
  let(:client) { FitgemOauth2::Client.new(client_id: client_id, client_secret: client_secret, token: token, user_id: user_id, unit_system: unit_system) }

  describe 'Basic request compatibility' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/test') { [200, {'Content-Type' => 'application/json'}, '{"status": "ok"}'] }
            stub.post('/1/test') { [200, {'Content-Type' => 'application/json'}, '{"created": true}'] }
          end
        end
      )
    end

    it 'handles GET requests with middleware' do
      response = client.get_call('test')
      expect(response).to be_a(Hash)
      expect(response['status']).to eq('ok')
    end

    it 'handles POST requests with middleware' do
      response = client.post_call('test', {data: 'test'})
      expect(response).to be_a(Hash)
      expect(response['created']).to be true
    end
  end

  describe 'JSON handling compatibility' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/json-data') { [200, {'Content-Type' => 'application/json'}, '{"user": {"name": "test"}}'] }
            stub.post('/1/json-data') { [200, {'Content-Type' => 'application/json'}, '{"success": true, "id": 123}'] }
          end
        end
      )
    end

    it 'parses JSON responses correctly' do
      response = client.get_call('json-data')
      expect(response).to be_a(Hash)
      expect(response).to have_key('user')
      expect(response['user']['name']).to eq('test')
    end

    it 'sends JSON data correctly' do
      response = client.post_call('json-data', {name: 'test'})
      expect(response).to be_a(Hash)
      expect(response['success']).to be true
      expect(response['id']).to eq(123)
    end
  end

  describe 'Error handling compatibility' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/not-found') { [404, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Not found"}]}'] }
            stub.get('/1/server-error') { [500, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Server error"}]}'] }
          end
        end
      )
    end

    it 'handles 404 errors correctly' do
      expect {
        client.get_call('not-found')
      }.to raise_error(FitgemOauth2::NotFoundError)
    end

    it 'handles 500 errors correctly' do
      expect {
        client.get_call('server-error')
      }.to raise_error(FitgemOauth2::ServerError)
    end
  end

  describe 'Authentication compatibility' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/protected') { [200, {'Content-Type' => 'application/json'}, '{"authenticated": true}'] }
            stub.get('/1/unauthorized') { [401, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Unauthorized"}]}'] }
          end
        end
      )
    end

    it 'handles authenticated requests' do
      response = client.get_call('protected')
      expect(response).to be_a(Hash)
      expect(response['authenticated']).to be true
    end

    it 'handles unauthorized requests' do
      expect {
        client.get_call('unauthorized')
      }.to raise_error(FitgemOauth2::UnauthorizedError)
    end
  end

  describe 'Connection management' do
    it 'maintains connection state across requests' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/state-test') { [200, {'Content-Type' => 'application/json'}, '{"state": "consistent"}'] }
          end
        end
      )

      response1 = client.get_call('state-test')
      response2 = client.get_call('state-test')

      expect(response1['state']).to eq('consistent')
      expect(response2['state']).to eq('consistent')
    end
  end

  describe 'Faraday 2.x specific features' do
    it 'works with Faraday 2.x connection object' do
      connection = client.send(:connection)
      expect(connection).to be_a(Faraday::Connection)
      expect(connection.url_prefix.to_s).to eq('https://api.fitbit.com/')
    end

    it 'maintains middleware stack compatibility' do
      connection = client.send(:connection)
      expect(connection.builder).to respond_to(:use, :adapter)
      expect(connection.builder.handlers).not_to be_empty
    end
  end
end