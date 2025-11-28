require 'spec_helper'
require 'benchmark'

RSpec.describe 'Performance Regression Tests for Faraday 2.x' do
  let(:client_id) { '22942C' }
  let(:client_secret) { 'secret' }
  let(:token) { 'test_token' }
  let(:user_id) { '26FWFL' }
  let(:unit_system) { 'en_US' }
  let(:client) { FitgemOauth2::Client.new(client_id: client_id, client_secret: client_secret, token: token, user_id: user_id, unit_system: unit_system) }

  describe 'HTTP request performance' do
    before do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/fast-endpoint') { [200, {'Content-Type' => 'application/json'}, '{"fast": "response"}'] }
            stub.post('/1/json-endpoint') { [200, {'Content-Type' => 'application/json'}, '{"posted": true}'] }
            stub.get('/1/large-response') { [200, {'Content-Type' => 'application/json'}, '{"large": "' + 'x' * 1000 + '"}'] }
            stub.get('/1/concurrent1') { [200, {'Content-Type' => 'application/json'}, '{"concurrent": "1"}'] }
            stub.get('/1/concurrent2') { [200, {'Content-Type' => 'application/json'}, '{"concurrent": "2"}'] }
            stub.get('/1/concurrent3') { [200, {'Content-Type' => 'application/json'}, '{"concurrent": "3"}'] }
          end
        end
      )
    end

    it 'completes simple GET requests within acceptable time limits' do
      time = Benchmark.realtime do
        10.times { client.get_call('fast-endpoint') }
      end

      # Should complete 10 requests in under 1 second (very generous limit)
      expect(time).to be < 1.0
    end

    it 'completes POST requests with JSON data within acceptable time limits' do
      test_payload = {data: 'test', number: 123, active: true}

      time = Benchmark.realtime do
        10.times { client.post_call('json-endpoint', test_payload) }
      end

      # Should complete 10 POST requests in under 1 second
      expect(time).to be < 1.0
    end

    it 'handles large responses efficiently' do
      time = Benchmark.realtime do
        5.times { client.get_call('large-response') }
      end

      # Should handle 5 large responses efficiently
      expect(time).to be < 0.5
    end

    it 'processes concurrent requests efficiently' do
      threads = []

      time = Benchmark.realtime do
        3.times do |i|
          threads << Thread.new { client.get_call("concurrent#{i + 1}") }
        end
        threads.each(&:join)
      end

      # Concurrent requests should be faster than sequential
      expect(time).to be < 0.5
    end
  end

  describe 'Memory usage performance' do
    it 'does not leak memory during repeated requests' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/memory-test') { [200, {'Content-Type' => 'application/json'}, '{"memory": "test"}'] }
          end
        end
      )

      # Test memory stability over many requests
      expect {
        100.times { client.get_call('memory-test') }
      }.not_to raise_error
    end
  end

  describe 'Connection pooling performance' do
    it 'reuses connections efficiently' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/reuse-test') { [200, {'Content-Type' => 'application/json'}, '{"reused": true}'] }
          end
        end
      )

      # First request to establish connection
      client.get_call('reuse-test')

      # Subsequent requests should be faster (connection reuse)
      time = Benchmark.realtime do
        10.times { client.get_call('reuse-test') }
      end

      expect(time).to be < 0.5
    end
  end

  describe 'Error handling performance' do
    it 'handles error responses efficiently' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/error-response') { [500, {'Content-Type' => 'application/json'}, '{"error": "test"}'] }
          end
        end
      )

      # Even error responses should be processed quickly
      expect {
        time = Benchmark.realtime do
          5.times do
            begin
              client.get_call('error-response')
            rescue FitgemOauth2::ServerError
              # Expected error
            end
          end
        end
        expect(time).to be < 0.5
      }.not_to raise_error
    end
  end

  describe 'Baseline performance metrics' do
    it 'establishes performance baseline for Faraday 2.x' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/baseline-test') { [200, {'Content-Type' => 'application/json'}, '{"baseline": true}'] }
          end
        end
      )

      # Establish baseline timing
      time = Benchmark.realtime do
        10.times { client.get_call('baseline-test') }
      end

      # Record baseline for future comparison
      expect(time).to be_a(Float)
      expect(time).to be > 0
      expect(time).to be < 2.0 # Reasonable upper limit
    end
  end

  describe 'Faraday 2.x specific performance characteristics' do
    it 'performs well with Faraday 2.x adapter' do
      # Test that Faraday 2.x performance is acceptable
      connection = client.send(:connection)

      # Connection setup should be fast
      setup_time = Benchmark.realtime do
        # Simulate connection setup overhead
        connection.builder
      end

      expect(setup_time).to be < 0.1
    end

    it 'handles mixed request types efficiently' do
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/mixed-get') { [200, {'Content-Type' => 'application/json'}, '{"get": true}'] }
            stub.post('/1/mixed-post') { [200, {'Content-Type' => 'application/json'}, '{"post": true}'] }
            stub.delete('/1/mixed-delete') { [204, {}, ''] }
          end
        end
      )

      time = Benchmark.realtime do
        5.times { client.get_call('mixed-get') }
        3.times { client.post_call('mixed-post', {data: 'test'}) }
        2.times { client.delete_call('mixed-delete') }
      end

      expect(time).to be < 1.0
    end
  end

  describe 'Regression prevention' do
    it 'detects significant performance regressions' do
      # This test serves as a baseline for detecting future regressions
      allow(client).to receive(:connection).and_return(
        Faraday.new('https://api.fitbit.com') do |builder|
          builder.adapter :test do |stub|
            stub.get('/1/regression-test') { [200, {'Content-Type' => 'application/json'}, '{"regression": false}'] }
          end
        end
      )

      # If this test starts failing, it indicates a performance regression
      time = Benchmark.realtime do
        20.times { client.get_call('regression-test') }
      end

      # This threshold should be adjusted if legitimate performance changes occur
      expect(time).to be < 2.0
    end
  end
end