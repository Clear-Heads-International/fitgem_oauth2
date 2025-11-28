require 'spec_helper'

RSpec.describe 'Faraday 2.x Error Handling' do
  let(:client_id) { '22942C' }
  let(:client_secret) { 'secret' }
  let(:token) { 'test_token' }
  let(:user_id) { '26FWFL' }
  let(:unit_system) { 'en_US' }
  let(:client) { FitgemOauth2::Client.new(client_id: client_id, client_secret: client_secret, token: token, user_id: user_id, unit_system: unit_system) }

  describe 'Connection-level errors' do
    it 'handles Faraday::ConnectionFailed errors' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/connection-failed') { raise Faraday::ConnectionFailed, 'Network unreachable' }
          end
        end
      )

      expect {
        client.get_call('connection-failed')
      }.to raise_error(Faraday::ConnectionFailed, 'Network unreachable')
    end

    it 'handles Faraday::TimeoutError for timeouts' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/timeout') { raise Faraday::TimeoutError, 'Request timeout' }
          end
        end
      )

      expect {
        client.get_call('timeout')
      }.to raise_error(Faraday::TimeoutError, 'Request timeout')
    end

    it 'handles Faraday::SSLError' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/ssl-error') { raise Faraday::SSLError, 'SSL verification failed' }
          end
        end
      )

      expect {
        client.get_call('ssl-error')
      }.to raise_error(Faraday::SSLError, 'SSL verification failed')
    end
  end

  describe 'HTTP status error handling' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/client-error') { [400, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Bad request"}]}'] }
            stub.get('/1/unauthorized') { [401, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Unauthorized"}]}'] }
            stub.get('/1/forbidden') { [403, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Forbidden"}]}'] }
            stub.get('/1/not-found') { [404, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Not found"}]}'] }
            stub.get('/1/server-error') { [500, {'Content-Type' => 'application/json'}, '{"errors": [{"message": "Server error"}]}'] }
          end
        end
      )
    end

    it 'handles HTTP 400 client errors' do
      expect {
        client.get_call('client-error')
      }.to raise_error(FitgemOauth2::BadRequestError)
    end

    it 'handles HTTP 401 unauthorized errors' do
      expect {
        client.get_call('unauthorized')
      }.to raise_error(FitgemOauth2::UnauthorizedError)
    end

    it 'handles HTTP 403 forbidden errors' do
      expect {
        client.get_call('forbidden')
      }.to raise_error(FitgemOauth2::ForbiddenError)
    end

    it 'handles HTTP 404 not found errors' do
      expect {
        client.get_call('not-found')
      }.to raise_error(FitgemOauth2::NotFoundError)
    end

    it 'handles HTTP 500 server errors' do
      expect {
        client.get_call('server-error')
      }.to raise_error(FitgemOauth2::ServerError)
    end
  end

  describe 'Response parsing errors' do
    it 'handles invalid JSON responses' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/invalid-json') { [200, {'Content-Type' => 'application/json'}, '{"invalid": json}'] }
          end
        end
      )

      expect {
        client.get_call('invalid-json')
      }.to raise_error(JSON::ParserError)
    end

    it 'handles empty responses gracefully' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/empty') { [204, {}, ''] }
          end
        end
      )

      result = client.get_call('empty')
      expect(result).to be_nil
    end
  end

  describe 'Response content handling' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/json-response') { [200, {'Content-Type' => 'application/json'}, '{"data": "value"}'] }
            stub.get('/1/complex-json') { [200, {'Content-Type' => 'application/json'}, '{"user": {"name": "test", "id": 123}}'] }
          end
        end
      )
    end

    it 'handles JSON responses correctly' do
      result = client.get_call('json-response')
      expect(result).to be_a(Hash)
      expect(result['data']).to eq('value')
    end

    it 'handles complex JSON responses correctly' do
      result = client.get_call('complex-json')
      expect(result).to be_a(Hash)
      expect(result).to have_key('user')
      expect(result['user']['name']).to eq('test')
      expect(result['user']['id']).to eq(123)
    end
  end
end