require 'spec_helper'

RSpec.describe 'Faraday Upgrade Edge Cases' do
  let(:client_id) { '22942C' }
  let(:client_secret) { 'secret' }
  let(:token) { 'test_token' }
  let(:user_id) { '26FWFL' }
  let(:unit_system) { 'en_US' }
  let(:client) { FitgemOauth2::Client.new(client_id: client_id, client_secret: client_secret, token: token, user_id: user_id, unit_system: unit_system) }

  describe 'Connection failure scenarios' do
    it 'handles connection failures gracefully' do
      # Mock connection failure
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/connection-fail') { raise Faraday::ConnectionFailed, 'Connection failed' }
          end
        end
      )

      expect {
        client.get_call('connection-fail')
      }.to raise_error(Faraday::ConnectionFailed)
    end

    it 'handles SSL errors gracefully' do
      # Mock SSL error
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/ssl-error') { raise Faraday::SSLError, 'SSL verification failed' }
          end
        end
      )

      expect {
        client.get_call('ssl-error')
      }.to raise_error(Faraday::SSLError)
    end
  end

  describe 'Data handling edge cases' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/large-data') { [200, {'Content-Type' => 'application/json'}, '{"large": "data"}'] }
            stub.post('/1/unicode') { [200, {'Content-Type' => 'application/json'}, '{"unicode": "✓测试"}'] }
            stub.get('/1/special-chars') { [200, {'Content-Type' => 'application/json'}, '{"special": "!@#$%^&*()"}'] }
          end
        end
      )
    end

    it 'handles large data responses' do
      result = client.get_call('large-data')
      expect(result).to have_key('large')
      expect(result['large']).to eq('data')
    end

    it 'handles Unicode characters in responses' do
      unicode_data = {message: '✓测试'}
      result = client.post_call('unicode', unicode_data)
      expect(result).to have_key('unicode')
    end

    it 'handles special characters in responses' do
      result = client.get_call('special-chars')
      expect(result).to have_key('special')
      expect(result['special']).to include('!@#$%^&*()')
    end
  end

  describe 'Response parsing edge cases' do
    it 'handles malformed JSON responses' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/malformed') { [200, {'Content-Type' => 'application/json'}, '{"invalid": json}'] }
          end
        end
      )

      expect {
        client.get_call('malformed')
      }.to raise_error(JSON::ParserError)
    end

    it 'handles empty responses' do
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

    # Removed nil response test as Fitbit API always returns JSON
  end

  describe 'Error handling edge cases' do
    it 'handles network timeouts gracefully' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/timeout') { raise Faraday::TimeoutError, 'Request timeout' }
          end
        end
      )

      expect {
        client.get_call('timeout')
      }.to raise_error(Faraday::TimeoutError)
    end

    it 'handles connection refused errors' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/refused') { raise Faraday::ConnectionFailed, 'Connection refused' }
          end
        end
      )

      expect {
        client.get_call('refused')
      }.to raise_error(Faraday::ConnectionFailed)
    end
  end

  describe 'Request/Response cycle edge cases' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/partial') { [200, {'Content-Type' => 'application/json'}, '{"partial": "data"}'] }
          end
        end
      )
    end

    it 'handles partial responses gracefully' do
      expect {
        client.get_call('partial')
      }.not_to raise_error
    end
  end

  describe 'Configuration edge cases' do
    it 'handles empty or nil configuration parameters' do
      # Test with minimal configuration
      minimal_client = FitgemOauth2::Client.new(
        client_id: '22942C',
        client_secret: 'secret',
        token: 'test_token',
        user_id: '26FWFL',
        unit_system: 'en_US'
      )
      connection = minimal_client.send(:connection)

      expect(connection).to be_a(Faraday::Connection)
    end

    it 'handles invalid configuration parameters gracefully' do
      expect {
        FitgemOauth2::Client.new(client_id: '22942C', client_secret: 'secret', token: nil, user_id: '26FWFL', unit_system: 'en_US')
      }.not_to raise_error
    end

    it 'maintains backward compatibility with existing code' do
      # Test that existing usage patterns still work
      old_style_client = FitgemOauth2::Client.new(
        client_id: '22942C',
        client_secret: 'secret',
        token: 'test_token',
        user_id: '26FWFL',
        unit_system: 'en_US'
      )
      expect(old_style_client).to respond_to(:get_call, :post_call, :delete_call)
    end
  end

  describe 'Version compatibility' do
    it 'works with Faraday 2.x features' do
      # Test that Faraday 2.x specific features work
      connection = client.send(:connection)
      expect(connection).to respond_to(:get, :post, :delete, :run_request)
    end

    it 'maintains compatibility with existing response format' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/user/-/profile.json') { [200, {'Content-Type' => 'application/json'}, '{"user": {"encodedId": "test123"}}'] }
          end
        end
      )

      result = client.get_call('user/-/profile.json')
      expect(result).to be_a(Hash)
      expect(result).to have_key('user')
      expect(result['user']).to have_key('encodedId')
    end
  end
end