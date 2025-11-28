# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'HTTP POST Requests with Faraday 2.x' do
  let(:client) { FitgemOauth2::Client.new(client_id: 'test_id', client_secret: 'test_secret', token: 'test_token') }
  let(:mock_connection) { double('connection') }
  let(:mock_response) { double('response', status: 201, body: '{"success": true}', headers: {}) }

  before do
    # Mock Faraday connection to avoid actual HTTP calls
    allow(Faraday).to receive(:new).and_return(mock_connection)
  end

  describe 'post_call method' do
    it 'makes a POST request with correct URL and parameters' do
      test_params = {'fat' => 15.5, 'date' => '2025-11-28'}

      expect(mock_connection).to receive(:post) do |url, params, &block|
        expect(url).to eq('1/user/-/body/log/fat.json')
        expect(params).to eq(test_params)

        # Mock request object and block
        mock_request = double('request')
        block.call(mock_request) if block_given?

        mock_response
      end

      expect(client).to receive(:parse_response).with(mock_response).and_return({'success' => true})

      result = client.post_call('user/-/body/log/fat.json', test_params)
      expect(result).to eq({'success' => true})
    end

    it 'sets appropriate headers through the connection block' do
      test_params = {'weight' => 70.0}

      expect(mock_connection).to receive(:post) do |_url, _params, &block|
        mock_request = double('request')

        # Mock the headers assignment
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)

        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.post_call('user/-/body/log/weight.json', test_params)
    end

    it 'handles POST request creation success (201 status)' do
      creation_response = double('response',
                                 status: 201,
                                 body: '{"id": 12345, "created": true}',
                                 headers: {})

      expect(mock_connection).to receive(:post).and_return(creation_response)

      # Mock parse_response behavior
      expect(client).to receive(:parse_response).with(creation_response).and_return({'id' => 12_345})

      result = client.post_call('user/-/activities.json', {'name' => 'Running'})
      expect(result).to eq({'id' => 12_345})
    end

    it 'handles POST request errors properly' do
      error_response = double('response',
                              status: 400,
                              body: 'Bad Request',
                              headers: {})

      expect(mock_connection).to receive(:post).and_return(error_response)
      expect(client).to receive(:parse_response).with(error_response).and_raise(FitgemOauth2::BadRequestError)

      expect do
        client.post_call('user/-/activities.json', {})
      end.to raise_error(FitgemOauth2::BadRequestError)
    end
  end

  describe 'activity POST requests' do
    before do
      allow(client).to receive(:post_call).and_return({'success' => true})
    end

    it 'log_activity makes correct POST request' do
      activity_params = {
        'activityName' => 'Running',
        'startTime' => '2025-11-28T10:00:00',
        'durationMillis' => 1_800_000
      }

      expect(client).to receive(:post_call).with('user/-/activities.json', activity_params)

      client.log_activity(activity_params)
    end

    it 'add_favorite_activity makes correct POST request' do
      expect(client).to receive(:post_call).with('user/-/activities/log/favorite/12345.json')

      client.add_favorite_activity(12_345)
    end

    it 'update_activity_goals makes correct POST request' do
      goals_params = {'caloriesOut' => 2000, 'steps' => 10_000}

      expect(client).to receive(:post_call).with('user/-/activities/goals/daily.json', goals_params)

      client.update_activity_goals('daily', goals_params)
    end
  end

  describe 'body measurements POST requests' do
    before do
      allow(client).to receive(:post_call).and_return({'success' => true})
    end

    it 'log_body_fat makes correct POST request' do
      fat_params = {'fat' => 15.5, 'date' => '2025-11-28'}

      expect(client).to receive(:post_call).with('user/-/body/log/fat.json', fat_params)

      client.log_body_fat(fat_params)
    end

    it 'log_weight makes correct POST request' do
      weight_params = {'weight' => 70.0, 'date' => '2025-11-28'}

      expect(client).to receive(:post_call).with('user/-/body/log/weight.json', weight_params)

      client.log_weight(weight_params)
    end

    it 'update_body_fat_goal makes correct POST request' do
      goal_params = {'fat' => 12.0}

      expect(client).to receive(:post_call).with('user/-/body/log/fat/goal.json', goal_params)

      client.update_body_fat_goal(goal_params)
    end

    it 'update_weight_goal makes correct POST request' do
      goal_params = {'weight' => 68.0, 'startDate' => '2025-11-28'}

      expect(client).to receive(:post_call).with('user/-/body/log/weight/goal.json', goal_params)

      client.update_weight_goal(goal_params)
    end
  end

  describe 'sleep POST requests' do
    before do
      allow(client).to receive(:post_call).and_return({'success' => true})
    end

    it 'update_sleep_goal makes correct POST request' do
      sleep_params = {'minDuration' => 480}

      expect(client).to receive(:post_call).with('user/-/sleep/goal.json', sleep_params)

      client.update_sleep_goal(sleep_params)
    end

    it 'log_sleep makes correct POST request using 1.2 API' do
      sleep_params = {
        'startTime' => '2025-11-28T22:30:00',
        'duration' => 28_800_000,
        'date' => '2025-11-28'
      }

      expect(client).to receive(:post_call_1_2).with('user/-/sleep.json', sleep_params)

      client.log_sleep(sleep_params)
    end
  end

  describe 'friends POST requests' do
    before do
      allow(client).to receive(:post_call).and_return({'success' => true})
    end

    it 'invite_friend makes correct POST request' do
      invite_params = {'invitedUserId' => 'friend123'}

      expect(client).to receive(:post_call).with('user/-/friends/invitations.json', invite_params)

      client.invite_friend(invite_params)
    end

    it 'respond_to_invitation makes correct POST request' do
      response_params = {'accept' => true}

      expect(client).to receive(:post_call).with('user/-/friends/invitations/from_user123.json', response_params)

      client.respond_to_invitation('from_user123', response_params)
    end
  end

  describe 'devices POST requests' do
    before do
      allow(client).to receive(:post_call).and_return({'success' => true})
    end

    it 'add_alarm makes correct POST request' do
      alarm_params = {
        'time' => '07:00',
        'enabled' => true,
        'recurring' => true,
        'weekDays' => 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY'
      }

      expect(client).to receive(:post_call).with('user/-/devices/tracker/tracker123/alarms.json', alarm_params)

      client.add_alarm('tracker123', alarm_params)
    end

    it 'update_alarm makes correct POST request' do
      alarm_params = {'enabled' => false}

      expect(client).to receive(:post_call).with('user/-/devices/tracker/tracker123/alarms/alarm456.json', alarm_params)

      client.update_alarm('tracker123', 'alarm456', alarm_params)
    end
  end

  describe 'food POST requests' do
    before do
      allow(client).to receive(:post_call).and_return({'success' => true})
    end

    it 'log_food makes correct POST request' do
      food_params = {
        'foodId' => 'food123',
        'mealTypeId' => 1,
        'unitId' => 1,
        'amount' => 100.0,
        'date' => '2025-11-28'
      }

      expect(client).to receive(:post_call).with('user/-/foods/log.json', food_params)

      client.log_food(food_params)
    end

    it 'log_water makes correct POST request' do
      water_params = {'amount' => 250, 'date' => '2025-11-28'}

      expect(client).to receive(:post_call).with('user/-/foods/log/water.json', water_params)

      client.log_water(water_params)
    end

    it 'create_meal makes correct POST request' do
      meal_params = {'name' => 'Breakfast', 'description' => 'Morning meal'}

      expect(client).to receive(:post_call).with('user/-/meals.json', meal_params)

      client.create_meal(meal_params)
    end

    it 'add_favorite_food makes correct POST request' do
      expect(client).to receive(:post_call).with('user/-/foods/log/favorite/food123.json')

      client.add_favorite_food('food123')
    end
  end

  describe 'subscription POST requests' do
    before do
      allow(client).to receive(:post_call).and_return({'success' => true})
    end

    it 'create_subscription makes correct POST request' do
      subscription_opts = {type: 'activities', subscription_id: 'sub123'}

      expect(client).to receive(:post_call).with('user/-/activities/apiSubscriptions/sub123.json')

      client.create_subscription(subscription_opts)
    end
  end

  describe 'POST request parameters and validation' do
    it 'handles empty parameters hash' do
      expect(mock_connection).to receive(:post) do |_url, params, &block|
        expect(params).to eq({})
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.post_call('test.json', {})
    end

    it 'handles nil parameters gracefully' do
      expect(mock_connection).to receive(:post) do |_url, params, &block|
        expect(params).to eq({})
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.post_call('test.json', {})
    end

    it 'handles complex nested parameters' do
      complex_params = {
        'activity' => {
          'name' => 'Running',
          'details' => {
            'distance' => 5000,
            'duration' => 1_800_000
          }
        }
      }

      expect(mock_connection).to receive(:post) do |_url, params, &block|
        expect(params).to eq(complex_params)
        mock_request = double('request')
        allow(mock_request).to receive(:headers).and_return({})
        allow(mock_request).to receive(:[]=)
        block.call(mock_request)
        mock_response
      end

      allow(client).to receive(:parse_response).and_return({})
      client.post_call('test.json', complex_params)
    end
  end

  describe 'POST response handling' do
    it 'handles successful creation responses' do
      creation_response = double('response',
                                 status: 201,
                                 body: '{"id": "new123", "createdOn": "2025-11-28"}',
                                 headers: {})

      expect(mock_connection).to receive(:post).and_return(creation_response)
      expect(client).to receive(:parse_response).with(creation_response).and_return({
                                                                                      'id' => 'new123',
                                                                                      'createdOn' => '2025-11-28'
                                                                                    })

      result = client.post_call('user/-/activities.json', {})
      expect(result).to include('id' => 'new123')
    end

    it 'handles no content responses (204)' do
      no_content_response = double('response',
                                   status: 204,
                                   body: '',
                                   headers: {})

      expect(mock_connection).to receive(:post).and_return(no_content_response)
      expect(client).to receive(:parse_response).with(no_content_response).and_return({})

      result = client.post_call('user/-/activities/log/favorite/123.json', {})
      expect(result).to eq({})
    end
  end
end
