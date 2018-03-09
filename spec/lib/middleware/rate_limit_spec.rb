require 'rails_helper'

describe Middleware::RateLimit do

  let(:app) do
    lambda do |env|
      [
        200,
        { 'Content-Type' => 'text/plain'},
        ['OK']
      ]
    end
  end
  let(:key) { 'sample_ip_address' }
  let(:key2) { 'sample_ip_address2' }
  let(:redis) { Redis.new(host: 'redis', port: 6379) }
  let(:request) { Rack::MockRequest.new(subject) }

  subject { described_class.new(app, redis) }

  before { redis.flushdb }

  describe '.initialize' do
    context 'when passing invalid arguments' do
      it { expect{described_class.new(app)}.to raise_error(ArgumentError) }
    end
  end

  describe '#call' do
    let(:response) { request.get('/', 'REMOTE_ADDR' => key ) }

    context 'when number of requests reaches the max limit' do
      before do
        allow_any_instance_of(Middleware::RequestLimit).to receive(:reached?) { true }
      end

      it 'returns a 429 status' do
        expect(response.status).to eq 429
      end

      it 'returns the rate limit headers' do
        expect(response.headers.has_key?('X-Rate-Limit-Limit')).to eq true
        expect(response.headers.has_key?('X-Rate-Limit-Remaining')).to eq true
        expect(response.headers.has_key?('X-Rate-Limit-Reset')).to eq true
      end

      it 'returns a rate limit exceed error message' do
        expect(response.body).to include "Rate limit exceeded."
      end
    end

    context 'when number of requests is less than the max request limit' do
      before do
        allow_any_instance_of(Middleware::RequestLimit).to receive(:reached?) { false }
      end

      it 'returns a 200 status' do
        expect(response.status).to eq 200
      end

      it 'returns the rate limit headers' do
        expect(response.headers.has_key?('X-Rate-Limit-Limit')).to eq true
        expect(response.headers.has_key?('X-Rate-Limit-Remaining')).to eq true
        expect(response.headers.has_key?('X-Rate-Limit-Reset')).to eq true
      end

      it 'returns the page response' do
        expect(response.body).to eq 'OK'
      end
    end

    context 'when visiting a page' do
      context 'when visting for the first time' do
        before do
          allow_any_instance_of(Redis).to receive(:get) { 1 }
        end

        it 'returns a 200 status' do
          expect(response.status).to eq 200
        end

        it 'decrements the value for \'rate limit remaining\' header' do
          expect(response.headers['X-Rate-Limit-Remaining']).to eq "99"
        end
      end

      context 'when visiting for the 10th times' do
        before do
          allow_any_instance_of(Redis).to receive(:get) { 10 }
        end

        it 'returns a 200 status' do
          expect(response.status).to eq 200
        end

        it 'decrements the value for \'rate limit remaining\' header' do
          expect(response.headers['X-Rate-Limit-Remaining']).to eq "90"
        end
      end

      context 'when visiting for the 100th times' do
        before do
          allow_any_instance_of(Redis).to receive(:get) { 100 }
        end

        it 'returns a 429 status' do
          expect(response.status).to eq 429
        end

        it 'decrements the value for \'rate limit remaining\' header' do
          expect(response.headers['X-Rate-Limit-Remaining']).to eq "0"
        end
      end

      context 'when visiting for the 500th times' do
        before do
          allow_any_instance_of(Redis).to receive(:get) { 500 }
        end

        it 'returns a 429 status' do
          expect(response.status).to eq 429
        end

        it 'decrements the value for \'rate limit remaining\' header' do
          expect(response.headers['X-Rate-Limit-Remaining']).to eq "-400"
        end
      end
    end

    context 'when request is coming from a different source' do
      it 'returns a different header values' do
        response2 = request.get('/', 'REMOTE_ADDR' => key2 )
        expect(response).to_not eq response2
      end

      it 'correctly calculates the limit' do
        r1 = request.get('/', 'REMOTE_ADDR' => key )
        r2 = request.get('/', 'REMOTE_ADDR' => key2 )
        r3 = request.get('/', 'REMOTE_ADDR' => key2 )
        expect(r1.headers['X-Rate-Limit-Remaining']).to eq '99'
        expect(r2.headers['X-Rate-Limit-Remaining']).to eq '99'
        expect(r3.headers['X-Rate-Limit-Remaining']).to eq '98'
      end
    end

    context 'when visiting a different page' do
      it 'correctly calculates the limit' do
        r1 = request.get('/', 'REMOTE_ADDR' => key )
        r2 = request.get('/home/index', 'REMOTE_ADDR' => key )
        r3 = request.get('/home/index', 'REMOTE_ADDR' => key )
        expect(r1.headers['X-Rate-Limit-Remaining']).to eq '99'
        expect(r2.headers['X-Rate-Limit-Remaining']).to eq '98'
        expect(r3.headers['X-Rate-Limit-Remaining']).to eq '97'
      end
    end
  end
end
