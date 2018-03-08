require 'rails_helper'

describe Middleware::RateLimit do

  let(:app) { lambda {|env| [200, {'Content-Type' => 'text/plain'}, ['OK']]} }
  let(:redis) { Redis.new(host: 'redis', port: 6379) }
  let(:request) { Rack::MockRequest.env_for("/", method: :get) }

  subject { described_class.new(app, redis) }

  describe '.initialize' do
    context 'when passing invalid arguments' do
      it { expect{described_class.new(app)}.to raise_error(ArgumentError) }
    end
  end

  describe '#call' do
    context 'when number of requests reaches the max limit' do
      before do
        Middleware::RequestLimit.any_instance.stub(:reached?).and_return(true)
      end

      it 'returns a 429 status' do
        response = subject.call(request)
        expect(response[0]).to eq 429
      end

      it 'returns the rate limit headers' do
        response = subject.call(request)
        expect(response[1].has_key?('X-Rate-Limit-Limit')).to eq true
        expect(response[1].has_key?('X-Rate-Limit-Remaining')).to eq true
        expect(response[1].has_key?('X-Rate-Limit-Reset')).to eq true
      end

      it 'returns a rate limit exceed error message' do
        response = subject.call(request)
        expect(response[2].first).to include "Rate limit exceeded."
      end
    end

    context 'when number of requests is less than the max request limit' do
      before do
        Middleware::RequestLimit.any_instance.stub(:reached?).and_return(false)
      end

      it 'returns a 200 status' do
        response = subject.call(request)
        expect(response[0]).to eq 200
      end

      it 'returns the rate limit headers' do
        response = subject.call(request)
        expect(response[1].has_key?('X-Rate-Limit-Limit')).to eq true
        expect(response[1].has_key?('X-Rate-Limit-Remaining')).to eq true
        expect(response[1].has_key?('X-Rate-Limit-Reset')).to eq true
      end

      it 'returns the page response' do
        response = subject.call(request)
        expect(response[2][0]).to eq 'OK'
      end
    end
  end


  describe 'a page visit' do
    context 'when visiting for the first time' do
    end

    context 'when visiting the 10th times' do
    end

    context 'when visiting the 100th times' do
    end

    context 'when visiting the 200th times' do
    end
  end

end
