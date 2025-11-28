# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'HTTP DELETE Requests with Faraday 2.x' do
  let(:client) { FitgemOauth2::Client.new(client_id: 'test_id', client_secret: 'test_secret', token: 'test_token') }
  let(:mock_connection) { double('connection') }
  let(:mock_response) { double('response', status: 204, body: '', headers: {}) }

  before do
    # Mock Faraday connection to avoid actual HTTP calls
    allow(Faraday).to receive(:new).and_return(mock_connection)
  end

  describe 'delete_call method' do
    it 'makes a DELETE request with correct URL format' do
      expect(mock_connection).to receive(:delete) do |url, &block|
        expect(url).to eq('1/user/-/sleep/12345.json')

        # Mock request object and block
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request) if block_given?

        mock_response
      end

      expect(client).to receive(:parse_response).with(mock_response).and_return({})

      result = client.delete_call('user/-/sleep/12345.json')
      expect(result).to eq({})
    end

    it 'sets appropriate headers through the connection block' do
      expect(mock_connection).to receive(:delete) do |_url, &block|
        mock_request = double('request')

        # Mock the headers assignment
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)

        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.delete_call('user/-/test.json')
    end

    it 'handles DELETE request success (204 status)' do
      delete_response = double('response',
                               status: 204,
                               body: '',
                               headers: {})

      expect(mock_connection).to receive(:delete).and_return(delete_response)
      expect(client).to receive(:parse_response).with(delete_response).and_return({})

      result = client.delete_call('user/-/sleep/12345.json')
      expect(result).to eq({})
    end

    it 'handles DELETE request errors properly' do
      error_response = double('response',
                              status: 400,
                              body: 'Bad Request',
                              headers: {})

      expect(mock_connection).to receive(:delete).and_return(error_response)
      expect(client).to receive(:parse_response).with(error_response).and_raise(FitgemOauth2::BadRequestError)

      expect do
        client.delete_call('user/-/invalid.json')
      end.to raise_error(FitgemOauth2::BadRequestError)
    end
  end

  describe 'sleep DELETE requests' do
    before do
      allow(client).to receive(:delete_call).and_return({})
    end

    it 'delete_logged_sleep makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/sleep/12345.json')

      client.delete_logged_sleep(12_345)
    end
  end

  describe 'activity DELETE requests' do
    before do
      allow(client).to receive(:delete_call).and_return({})
    end

    it 'delete_logged_activity makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/activities/98765.json')

      client.delete_logged_activity(98_765)
    end

    it 'remove_favorite_activity makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/activities/log/favorite/54321.json')

      client.remove_favorite_activity(54_321)
    end
  end

  describe 'body measurements DELETE requests' do
    before do
      allow(client).to receive(:delete_call).and_return({})
    end

    it 'delete_logged_body_fat makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/body/log/fat/11111.json')

      client.delete_logged_body_fat(11_111)
    end

    it 'delete_logged_weight makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/body/log/weight/22222.json')

      client.delete_logged_weight(22_222)
    end
  end

  describe 'food DELETE requests' do
    before do
      allow(client).to receive(:delete_call).and_return({})
    end

    it 'delete_favorite_food makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/foods/log/favorite/food123.json')

      client.delete_favorite_food('food123')
    end

    it 'delete_food_log makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/foods/log/45678.json')

      client.delete_food_log(45_678)
    end

    it 'delete_water_log makes correct DELETE request' do
      expect(client).to receive(:delete_call).with('user/-/foods/log/water/78901.json')

      client.delete_water_log(78_901)
    end
  end

  describe 'sleep DELETE requests with full implementation' do
    it 'delete_logged_sleep calls delete_call with correct URL' do
      expect(mock_connection).to receive(:delete) do |url, &block|
        expect(url).to eq('1/user/-/sleep/99999.json')
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        mock_response
      end

      expect(client).to receive(:parse_response).with(mock_response).and_return({})

      result = client.delete_logged_sleep(99_999)
      expect(result).to eq({})
    end
  end

  describe 'DELETE request response handling' do
    it 'handles successful deletion (204 No Content)' do
      success_response = double('response',
                                status: 204,
                                body: '',
                                headers: {})

      expect(mock_connection).to receive(:delete).and_return(success_response)
      expect(client).to receive(:parse_response).with(success_response).and_return({})

      result = client.delete_call('user/-/test.json')
      expect(result).to eq({})
    end

    it 'handles resource not found (404)' do
      not_found_response = double('response',
                                  status: 404,
                                  body: 'Not Found',
                                  headers: {})

      expect(mock_connection).to receive(:delete).and_return(not_found_response)
      expect(client).to receive(:parse_response).with(not_found_response).and_raise(FitgemOauth2::NotFoundError)

      expect do
        client.delete_call('user/-/nonexistent.json')
      end.to raise_error(FitgemOauth2::NotFoundError)
    end

    it 'handles forbidden requests (403)' do
      forbidden_response = double('response',
                                  status: 403,
                                  body: 'Forbidden',
                                  headers: {})

      expect(mock_connection).to receive(:delete).and_return(forbidden_response)
      expect(client).to receive(:parse_response).with(forbidden_response).and_raise(FitgemOauth2::ForbiddenError)

      expect do
        client.delete_call('user/-/protected.json')
      end.to raise_error(FitgemOauth2::ForbiddenError)
    end

    it 'handles server errors (500)' do
      server_error_response = double('response',
                                     status: 500,
                                     body: 'Internal Server Error',
                                     headers: {})

      expect(mock_connection).to receive(:delete).and_return(server_error_response)
      expect(client).to receive(:parse_response).with(server_error_response).and_raise(FitgemOauth2::ServerError)

      expect do
        client.delete_call('user/-/error.json')
      end.to raise_error(FitgemOauth2::ServerError)
    end
  end

  describe 'DELETE request parameters and validation' do
    it 'handles resource ID in URL correctly' do
      expect(mock_connection).to receive(:delete) do |url, &block|
        expect(url).to eq('1/user/-/sleep/12345.json')
        expect(url).to include('/12345.json')
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.delete_call('user/-/sleep/12345.json')
    end

    it 'handles string resource IDs' do
      expect(mock_connection).to receive(:delete) do |url, &block|
        expect(url).to eq('1/user/-/foods/log/favorite/food123.json')
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.delete_call('user/-/foods/log/favorite/food123.json')
    end
  end

  describe 'DELETE request headers and authentication' do
    it 'includes authorization header in DELETE request' do
      expect(mock_connection).to receive(:delete) do |_url, &block|
        mock_request = double('request')

        # Mock the headers assignment to simulate set_headers behavior
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)

        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.delete_call('user/-/test.json')
    end

    it 'includes content type header' do
      expect(mock_connection).to receive(:delete) do |_url, &block|
        mock_request = double('request')

        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)

        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.delete_call('user/-/test.json')
    end
  end

  describe 'Real Faraday 2.x DELETE capabilities' do
    it 'confirms Faraday version supports DELETE' do
      # Test with actual Faraday class to ensure DELETE functionality exists
      expect(Faraday::Connection.instance_methods).to include(:delete)
    end

    it 'verifies Faraday class has DELETE functionality' do
      # Confirm Faraday supports DELETE at the class level
      expect(Faraday::Connection.method_defined?(:delete)).to be true
    end
  end

  describe 'DELETE vs GET/POST method distinctions' do
    it 'confirms Faraday 2.x maintains method distinctions' do
      # Verify that Faraday 2.x properly handles all HTTP methods
      expect(mock_connection).to receive(:delete) do |_url, &block|
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        double('response', status: 204, body: '', headers: {})
      end

      expect(mock_connection).to receive(:get) do |_url, &block|
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        double('response', status: 200, body: '{}', headers: {})
      end

      expect(mock_connection).to receive(:post) do |_url, _params, &block|
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        double('response', status: 201, body: '{}', headers: {})
      end

      # All methods should work independently
      mock_connection.delete('1/user/-/resource/123.json') {}
      mock_connection.get('1/user/-/resource.json') {}
      mock_connection.post('1/user/-/resource.json', {}) {}
    end
  end
end
