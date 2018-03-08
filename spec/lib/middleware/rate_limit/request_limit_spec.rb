require 'rails_helper'

describe Middleware::RequestLimit do

  let(:redis) { Redis.new(host: 'redis', port: 6379) }
  let(:redis_key) { 'sample_ip_address' }

  subject { described_class.new(redis, redis_key: redis_key) }

  describe '.initialize' do
    context 'when passing invalid arguments' do
      it { expect{described_class.new(redis)}.to raise_error(ArgumentError) }
    end

    context 'when passing valid arguments' do
      it 'sets the redis object' do
        expect(subject.instance_variable_get(:@redis)).to eq redis
      end

      it 'sets the default 100 max requests' do
        expect(subject.instance_variable_get(:@max_requests)).to eq 100
      end

      it 'sets the default 1hour time window' do
        expect(subject.instance_variable_get(:@time_window)).to eq 3600
      end

      it 'sets the redis key' do
        expect(subject.instance_variable_get(:@redis_key)).to eq redis_key
      end

      it 'calls the process method' do
        allow_any_instance_of(described_class).to receive(:process) { true }
        expect(
          described_class.new(redis, redis_key: redis_key)
        ).to have_received(:process)
      end
    end
  end

  describe '#reached?' do
    context 'when count is more than the max requests' do
      it 'returns true' do
        allow(redis).to receive(:get) { 101 }
        expect(subject.reached?).to eq true
      end
    end

    context 'when count is equal the max requests' do
      it 'returns true' do
        allow(redis).to receive(:get) { 100 }
        expect(subject.reached?).to eq true
      end
    end

    context 'when count is less than the max requests' do
      it 'returns false' do
        allow(redis).to receive(:get) { 5 }
        expect(subject.reached?).to eq false
      end
    end
  end

  describe '#rate_limit_headers' do
    let(:sample_time_til_reset) { (Time.now.to_i + 1.hour).to_s }

    before do
      allow(redis).to receive(:get) { 5 }
      allow(subject).to receive(:time_til_reset) { sample_time_til_reset }
    end

    it 'contains the number of max requests' do
      expect(subject.rate_limit_headers['X-Rate-Limit-Limit']).to eq 100
    end

    it 'contains the remaining limit' do
      expect(subject.rate_limit_headers['X-Rate-Limit-Remaining']).to eq '95'
    end

    it 'contains the time to reset the limit' do
      expect(subject.rate_limit_headers['X-Rate-Limit-Reset']).to eq sample_time_til_reset
    end
  end

  describe '#limit_reached_message' do
    let(:sample_remaining_time) { (Time.now.to_i + 1.hour).to_s }

    before do
      allow(redis).to receive(:get) { 5 }
      allow_any_instance_of(described_class).to receive(:remaining_time_til_reset) { sample_remaining_time }
    end

    it 'contains a message that the limit has been reached' do
      expect(
        JSON.parse(subject.limit_reached_message)['message']
      ).to include 'Rate limit exceeded.'
    end

    it 'contains the time remaining til reset' do
      expect(
        JSON.parse(subject.limit_reached_message)['message']
      ).to include sample_remaining_time
    end
  end
end