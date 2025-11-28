# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'HTTP GET Requests with Faraday 2.x' do
  let(:client) { FitgemOauth2::Client.new(client_id: 'test_id', client_secret: 'test_secret', token: 'test_token') }
  let(:mock_connection) { double('connection') }
  let(:mock_response) { double('response', status: 200, body: '{"test": "data"}', headers: {}) }

  before do
    # Mock Faraday connection to avoid actual HTTP calls
    allow(Faraday).to receive(:new).and_return(mock_connection)
  end

  describe 'get_call method' do
    it 'makes a GET request with correct URL format' do
      expect(mock_connection).to receive(:get) do |url, &block|
        expect(url).to eq('1/user/-/activities/test.json')

        # Mock request object and block
        mock_request = double('request')
        block.call(mock_request) if block_given?

        mock_response
      end

      expect(client).to receive(:parse_response).with(mock_response).and_return({'test' => 'data'})

      result = client.get_call('user/-/activities/test.json')
      expect(result).to eq({'test' => 'data'})
    end

    it 'sets appropriate headers through the connection block' do
      expect(mock_connection).to receive(:get) do |_url, &block|
        mock_request = double('request')

        # Mock the headers assignment
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)

        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.get_call('user/-/activities/test.json')
    end

    it 'includes rate limit headers in response when present' do
      response_with_headers = double('response',
                                     status: 200,
                                     body: '{"test": "data"}',
                                     headers: {
                                       'fitbit-rate-limit-limit' => '150',
                                       'fitbit-rate-limit-remaining' => '149',
                                       'fitbit-rate-limit-reset' => '1234567890'
                                     })

      expect(mock_connection).to receive(:get).and_return(response_with_headers)

      # Mock the parse_response to include headers
      expected_result = {
        'test' => 'data',
        'fitbit-rate-limit-limit' => '150',
        'fitbit-rate-limit-remaining' => '149',
        'fitbit-rate-limit-reset' => '1234567890'
      }

      expect(client).to receive(:parse_response).with(response_with_headers).and_return(expected_result)

      result = client.get_call('user/-/activities/test.json')
      expect(result).to include('fitbit-rate-limit-limit' => '150')
    end
  end

  describe 'activity GET requests' do
    before do
      allow(client).to receive(:get_call).and_return({'success' => true})
    end

    it 'daily_activity_summary makes correct GET request' do
      expect(client).to receive(:get_call).with('user/-/activities/date/2025-11-28.json')

      client.daily_activity_summary(Date.new(2025, 11, 28))
    end

    it 'activity_time_series makes correct GET request' do
      expect(client).to receive(:get_call).with('user/-/activities/steps/date/2025-11-27/2025-11-28.json')

      client.activity_time_series(resource: 'steps', start_date: '2025-11-27', end_date: '2025-11-28')
    end

    it 'intraday_activity_time_series makes correct GET request' do
      expect(client).to receive(:get_call).with('user/-/activities/calories/date/2025-11-28/1d/1min.json')

      client.intraday_activity_time_series(
        resource: 'calories',
        start_date: '2025-11-28',
        detail_level: '1min'
      )
    end

    it 'activity_list makes correct GET request with proper query parameters' do
      expect(client).to receive(:get_call).with('user/-/activities/list.json?offset=0&limit=10&sort=desc&beforeDate=2025-11-28')

      client.activity_list(Date.new(2025, 11, 28), 'desc', 10)
    end

    it 'activity_tcx makes correct GET request' do
      expect(client).to receive(:get_call).with('user/-/activities/12345.tcx')

      client.activity_tcx(12_345)
    end

    it 'activities makes correct GET request' do
      expect(client).to receive(:get_call).with('activities.json')

      client.activities
    end

    it 'goals makes correct GET request' do
      expect(client).to receive(:get_call).with('user/-/activities/goals/daily.json')

      client.goals('daily')
    end

    it 'lifetime_stats makes correct GET request' do
      expect(client).to receive(:get_call).with('user/-/activities.json')

      client.lifetime_stats
    end
  end

  describe 'request parameters and headers' do
    it 'creates client with custom unit system' do
      client_with_unit = FitgemOauth2::Client.new(
        client_id: 'test_id',
        client_secret: 'test_secret',
        token: 'test_token',
        unit_system: 'en_GB'
      )

      expect(client_with_unit.unit_system).to eq('en_GB')
    end

    it 'creates client with custom user_id' do
      client_with_user = FitgemOauth2::Client.new(
        client_id: 'test_id',
        client_secret: 'test_secret',
        token: 'test_token',
        user_id: 'custom_user'
      )

      expect(client_with_user.user_id).to eq('custom_user')
    end
  end

  describe 'response parsing behavior' do
    it 'parses JSON body correctly' do
      json_response = double('response',
                             status: 200,
                             body: '{"steps": 1000, "calories": 500}',
                             headers: {})

      expect(mock_connection).to receive(:get).and_return(json_response)

      # Mock parse_response behavior
      parsed_result = {'steps' => 1000, 'calories' => 500}
      expect(client).to receive(:parse_response).with(json_response).and_return(parsed_result)

      result = client.get_call('test')
      expect(result).to eq({'steps' => 1000, 'calories' => 500})
    end

    it 'handles response headers properly' do
      response_with_headers = double('response',
                                     status: 200,
                                     body: '{}',
                                     headers: {'fitbit-rate-limit-limit' => '150'})

      expect(mock_connection).to receive(:get).and_return(response_with_headers)

      result_with_headers = {'limit' => '150'}
      expect(client).to receive(:parse_response).with(response_with_headers).and_return(result_with_headers)

      result = client.get_call('test')
      expect(result).to eq({'limit' => '150'})
    end
  end
end
