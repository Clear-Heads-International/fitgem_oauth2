# frozen_string_literal: true

require 'fitgem_oauth2/activity.rb'
require 'fitgem_oauth2/body_measurements.rb'
require 'fitgem_oauth2/devices.rb'
require 'fitgem_oauth2/errors.rb'
require 'fitgem_oauth2/food.rb'
require 'fitgem_oauth2/friends.rb'
require 'fitgem_oauth2/heartrate.rb'
require 'fitgem_oauth2/sleep.rb'
require 'fitgem_oauth2/subscriptions.rb'
require 'fitgem_oauth2/users.rb'
require 'fitgem_oauth2/utils.rb'
require 'fitgem_oauth2/version.rb'

require 'base64'
require 'faraday'
require 'faraday/net_http'

module FitgemOauth2
  class Client
    DEFAULT_USER_ID = '-'
    API_VERSION = '1'

    attr_reader :client_id
    attr_reader :client_secret
    attr_reader :token
    attr_reader :user_id
    attr_reader :unit_system

    # Initializes a new Fitbit API client
    #
    # @param opts [Hash] Configuration options for the client
    # @option opts [String] :client_id The OAuth2 client ID for your Fitbit application
    # @option opts [String] :client_secret The OAuth2 client secret for your Fitbit application
    # @option opts [String] :token The OAuth2 access token for making authenticated requests
    # @option opts [String] :user_id The Fitbit user ID (defaults to '-' for current user)
    # @option opts [String] :unit_system The unit system to use ('en_US', 'metric', etc.)
    #
    # @note This client uses Faraday ~> 2.6 for HTTP operations. The connection is
    #       automatically configured with the net_http adapter and URL encoding.
    #
    # @example Initialize with required parameters
    #   client = FitgemOauth2::Client.new(
    #     client_id: 'your_client_id',
    #     client_secret: 'your_client_secret',
    #     token: 'access_token'
    #   )
    #
    # @example Initialize with all parameters
    #   client = FitgemOauth2::Client.new(
    #     client_id: 'your_client_id',
    #     client_secret: 'your_client_secret',
    #     token: 'access_token',
    #     user_id: '123XYZ',
    #     unit_system: 'metric'
    #   )
    #
    # @raise [FitgemOauth2::InvalidArgumentError] If required options are missing
    def initialize(opts)
      missing = %i[client_id client_secret token] - opts.keys
      raise FitgemOauth2::InvalidArgumentError, "Missing required options: #{missing.join(',')}" unless missing.empty?

      @client_id = opts[:client_id]
      @client_secret = opts[:client_secret]
      @token = opts[:token]
      @user_id = (opts[:user_id] || DEFAULT_USER_ID)
      @unit_system = opts[:unit_system]
      @connection = Faraday.new('https://api.fitbit.com') do |faraday|
        faraday.request :url_encoded
        faraday.adapter :net_http
      end
    end

    def refresh_access_token(refresh_token)
      response = connection.post('/oauth2/token') do |request|
        encoded = Base64.strict_encode64("#{@client_id}:#{@client_secret}")
        request.headers['Authorization'] = "Basic #{encoded}"
        request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        request.params['grant_type'] = 'refresh_token'
        request.params['refresh_token'] = refresh_token
      end
      JSON.parse(response.body)
    end

    def revoke_token(token)
      response = connection.post('/oauth2/revoke') do |request|
        encoded = Base64.strict_encode64("#{@client_id}:#{@client_secret}")
        request.headers['Authorization'] = "Basic #{encoded}"
        request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        request.params['token'] = token
      end
      JSON.parse(response.body)
    end

    # Makes a GET request to the Fitbit API v1
    #
    # @param url [String] The API endpoint (without version prefix)
    # @return [Hash] Parsed JSON response from the API
    #
    # @note Uses Faraday ~> 2.6 for HTTP requests with automatic authentication headers
    # @example Get user profile
    #   response = client.get_call('user/-/profile.json')
    def get_call(url)
      url = "#{API_VERSION}/#{url}"
      response = connection.get(url) {|request| set_headers(request) }
      parse_response(response)
    end

    # Makes a GET request to the Fitbit API v1.2
    #
    # @param url [String] The API endpoint (without version prefix)
    # @return [Hash] Parsed JSON response from the API
    #
    # @note This method is needed because Fitbit API supports both v1 and v1.2 as of current date
    # @note Uses Faraday ~> 2.6 for HTTP requests with automatic authentication headers
    # @example Get activity data
    #   response = client.get_call_1_2('user/-/activities/date/today.json')
    def get_call_1_2(url)
      url = "1.2/#{url}"
      response = connection.get(url) {|request| set_headers(request) }
      parse_response(response)
    end

    # Makes a POST request to the Fitbit API v1
    #
    # @param url [String] The API endpoint (without version prefix)
    # @param params [Hash] Request parameters to be sent as form data
    # @return [Hash] Parsed JSON response from the API
    #
    # @note Uses Faraday ~> 2.6 for HTTP requests with automatic authentication headers
    # @example Log an activity
    #   response = client.post_call('user/-/activities.json', {
    #     activityName: 'Running',
    #     durationMillis: 1800000
    #   })
    def post_call(url, params={})
      url = "#{API_VERSION}/#{url}"
      response = connection.post(url, params) {|request| set_headers(request) }
      parse_response(response)
    end

    # Makes a POST request to the Fitbit API v1.2
    #
    # @param url [String] The API endpoint (without version prefix)
    # @param params [Hash] Request parameters to be sent as form data
    # @return [Hash] Parsed JSON response from the API
    #
    # @note Uses Faraday ~> 2.6 for HTTP requests with automatic authentication headers
    # @example Create a food log
    #   response = client.post_call_1_2('user/-/foods/log.json', {
    #     foodId: '12345',
    #     mealTypeId: 1,
    #     unitId: 1,
    #     amount: 100.0
    #   })
    def post_call_1_2(url, params={})
      url = "1.2/#{url}"
      response = connection.post(url, params) {|request| set_headers(request) }
      parse_response(response)
    end

    # Makes a DELETE request to the Fitbit API v1
    #
    # @param url [String] The API endpoint (without version prefix)
    # @return [Hash] Parsed JSON response from the API
    #
    # @note Uses Faraday ~> 2.6 for HTTP requests with automatic authentication headers
    # @example Delete an activity log
    #   response = client.delete_call('user/-/activities/12345.json')
    def delete_call(url)
      url = "#{API_VERSION}/#{url}"
      response = connection.delete(url) {|request| set_headers(request) }
      parse_response(response)
    end

    private

    attr_reader :connection

    def set_headers(request)
      request.headers['Authorization'] = "Bearer #{token}"
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request.headers['Accept-Language'] = unit_system unless unit_system.nil?
    end

    def parse_response(response)
      headers_to_keep = %w[fitbit-rate-limit-limit fitbit-rate-limit-remaining fitbit-rate-limit-reset]

      error_handler = {
        200 => lambda {
          parsed_body = JSON.parse(response.body)
          result = parsed_body.is_a?(Array) ? {'body' => parsed_body} : parsed_body
          headers = response.headers.to_hash.keep_if do |k, _v|
            headers_to_keep.include? k
          end
          result.merge!(headers)
        },
        201 => -> { {} },
        204 => -> { nil },
        400 => -> { raise FitgemOauth2::BadRequestError },
        401 => -> { raise FitgemOauth2::UnauthorizedError },
        403 => -> { raise FitgemOauth2::ForbiddenError },
        404 => -> { raise FitgemOauth2::NotFoundError },
        429 => -> { raise FitgemOauth2::ApiLimitError },
        500..599 => -> { raise FitgemOauth2::ServerError }
      }

      fn = error_handler.find {|k, _| k === response.status }
      raise StandardError, "Unexpected response status #{response.status}" if fn.nil?

      fn.last.call
    end
  end
end
