# frozen_string_literal: true

require 'spec_helper'

describe 'Faraday Compatibility Tests' do
  let(:client) { FactoryBot.build(:client) }
  let(:test_params) { {test: 'value'} }

  describe 'Connection Setup' do
    it 'creates a Faraday connection with correct URL' do
      connection = client.send(:connection)
      expect(connection).to be_a(Faraday::Connection)
      expect(connection.url_prefix.to_s).to eq('https://api.fitbit.com/')
    end

    it 'connection uses appropriate adapter' do
      connection = client.send(:connection)
      expect(connection.builder.handlers).not_to be_empty
    end

    it 'has the correct SSL configuration' do
      connection = client.send(:connection)
      expect(connection.ssl).to be_a(Faraday::SSLOptions)
    end
  end

  describe 'HTTP Method Compatibility' do
    before do
      # Mock Faraday connection to test actual HTTP methods
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/test') { [200, {'Content-Type' => 'application/json'}, '{"data": "GET response"}'] }
            stub.post('/1/test') { [200, {'Content-Type' => 'application/json'}, '{"data": "POST response"}'] }
            stub.delete('/1/test') { [204, {}, ''] }
          end
        end
      )
    end

    describe '#get_call' do
      it 'sends GET requests with proper headers' do
        result = client.get_call('test')
        expect(result).to have_key('data')
        expect(result['data']).to eq('GET response')
      end
    end

    describe '#post_call' do
      it 'sends POST requests with parameters' do
        result = client.post_call('test', test_params)
        expect(result).to have_key('data')
        expect(result['data']).to eq('POST response')
      end
    end

    describe '#delete_call' do
      it 'sends DELETE requests with proper headers' do
        result = client.delete_call('test')
        expect(result).to be_nil # 204 response returns nil
      end
    end
  end

  describe 'Request Headers' do
    let(:mock_headers) { double('headers') }
    let(:mock_request) { double('request', headers: mock_headers) }

    it 'sets proper authorization header' do
      expect(mock_headers).to receive(:[]=).with('Authorization', /Bearer .+/)
      expect(mock_headers).to receive(:[]=).with('Content-Type', 'application/x-www-form-urlencoded')
      client.send(:set_headers, mock_request)
    end

    it 'sets accept-language header when unit system is present' do
      client_with_units = FitgemOauth2::Client.new(
        client_id: 'test',
        client_secret: 'test',
        token: 'test',
        unit_system: 'en_US'
      )
      expect(mock_headers).to receive(:[]=).with('Authorization', 'Bearer test')
      expect(mock_headers).to receive(:[]=).with('Content-Type', 'application/x-www-form-urlencoded')
      expect(mock_headers).to receive(:[]=).with('Accept-Language', 'en_US')
      client_with_units.send(:set_headers, mock_request)
    end
  end

  describe 'Response Handling' do
    let(:success_response) do
      response = double('Faraday::Response')
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return('{"success": true}')
      allow(response).to receive(:headers).and_return({
                                                        'fitbit-rate-limit-limit' => '150',
                                                        'fitbit-rate-limit-remaining' => '149',
                                                        'fitbit-rate-limit-reset' => '1234567890'
                                                      })
      response
    end

    it 'handles successful JSON response correctly' do
      result = client.send(:parse_response, success_response)
      expect(result['success']).to be true
      expect(result['fitbit-rate-limit-limit']).to eq('150')
    end

    it 'handles array responses correctly' do
      response = double('Faraday::Response')
      allow(response).to receive(:status).and_return(200)
      allow(response).to receive(:body).and_return('[{"item": "value1"}, {"item": "value2"}]')
      allow(response).to receive(:headers).and_return({})

      result = client.send(:parse_response, response)
      expect(result).to have_key('body')
      expect(result['body']).to be_an(Array)
    end
  end

  describe 'Error Handling' do
    context 'HTTP Errors' do
      let(:bad_request_response) do
        response = double('Faraday::Response')
        allow(response).to receive(:status).and_return(400)
        response
      end

      let(:unauthorized_response) do
        response = double('Faraday::Response')
        allow(response).to receive(:status).and_return(401)
        response
      end

      let(:not_found_response) do
        response = double('Faraday::Response')
        allow(response).to receive(:status).and_return(404)
        response
      end

      let(:server_error_response) do
        response = double('Faraday::Response')
        allow(response).to receive(:status).and_return(500)
        response
      end

      it 'raises BadRequestError for 400 status' do
        expect do
          client.send(:parse_response, bad_request_response)
        end.to raise_error(FitgemOauth2::BadRequestError)
      end

      it 'raises UnauthorizedError for 401 status' do
        expect do
          client.send(:parse_response, unauthorized_response)
        end.to raise_error(FitgemOauth2::UnauthorizedError)
      end

      it 'raises NotFoundError for 404 status' do
        expect do
          client.send(:parse_response, not_found_response)
        end.to raise_error(FitgemOauth2::NotFoundError)
      end

      it 'raises ServerError for 500 status' do
        expect do
          client.send(:parse_response, server_error_response)
        end.to raise_error(FitgemOauth2::ServerError)
      end
    end
  end

  describe 'OAuth2 Flow Compatibility' do
    let(:refresh_token) { 'test_refresh_token' }
    let(:token_response) do
      {
        'access_token' => 'new_access_token',
        'refresh_token' => 'new_refresh_token',
        'expires_in' => 3600,
        'token_type' => 'Bearer'
      }
    end

    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.post('/oauth2/token') { [200, {}, token_response.to_json] }
            stub.post('/oauth2/revoke') { [200, {}, '{}'] }
          end
        end
      )
    end

    it 'refreshes access token successfully' do
      result = client.refresh_access_token(refresh_token)
      expect(result['access_token']).to eq('new_access_token')
      expect(result['token_type']).to eq('Bearer')
    end

    it 'revokes token successfully' do
      result = client.revoke_token('test_token')
      expect(result).to be_a(Hash)
    end
  end

  describe 'Version 1.2 API Compatibility' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1.2/test') { [200, {'Content-Type' => 'application/json'}, '{"data": "v1.2 response"}'] }
            stub.post('/1.2/test') { [200, {'Content-Type' => 'application/json'}, '{"data": "v1.2 POST response"}'] }
          end
        end
      )
    end

    it 'supports v1.2 GET calls' do
      result = client.get_call_1_2('test')
      expect(result).to have_key('data')
      expect(result['data']).to eq('v1.2 response')
    end

    it 'supports v1.2 POST calls' do
      result = client.post_call_1_2('test', test_params)
      expect(result).to have_key('data')
      expect(result['data']).to eq('v1.2 POST response')
    end
  end

  describe 'Connection Configuration' do
    it 'uses the correct API version' do
      expect(FitgemOauth2::Client::API_VERSION).to eq('1')
    end

    it 'has the correct default user ID' do
      expect(FitgemOauth2::Client::DEFAULT_USER_ID).to eq('-')
    end

    it 'can be initialized with custom options' do
      custom_client = FitgemOauth2::Client.new(
        client_id: 'custom_id',
        client_secret: 'custom_secret',
        token: 'custom_token',
        user_id: 'custom_user',
        unit_system: 'en_GB'
      )

      expect(custom_client.client_id).to eq('custom_id')
      expect(custom_client.client_secret).to eq('custom_secret')
      expect(custom_client.token).to eq('custom_token')
      expect(custom_client.user_id).to eq('custom_user')
      expect(custom_client.unit_system).to eq('en_GB')
    end
  end
end
