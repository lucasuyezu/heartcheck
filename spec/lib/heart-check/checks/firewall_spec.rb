require 'spec_helper'

describe Heartcheck::Checks::Firewall do
  let(:service_opts)     { { port: 443, host: 'lala.com' } }
  let(:instance_default) { described_class.new.tap { |c| c.add_service service_opts } }

  describe '#services' do
    subject { described_class.new }

    it 'returns array of FirewallService' do
      subject.add_service(service_opts)
      expect(subject.services.first).to be_a(Heartcheck::Services::Firewall)
    end
  end

  describe '#validate' do
    subject { instance_default }

    context 'without proxy' do
      context 'with success' do
        it 'calls Net::Telnet with valid params' do
          expect(Net::Telnet).to receive(:new).with('Port' => 443, 'Host' => 'lala.com', 'Timeout' => 2)
          subject.validate
        end
      end

      context 'with success' do
        before { allow(Net::Telnet).to receive(:new).and_raise(Timeout::Error.new) }

        it 'adds error message' do
          subject.validate

          expect(subject.instance_variable_get(:@errors)).to eq(['connection refused on: lala.com:443'])
        end

        it 'calls block when given' do
          subject = described_class.new.tap do |c|
            c.add_service(service_opts)
            c.on_error { |errors, service| errors << "Custom error message in port #{service.port}" }
          end
          subject.validate

          expect(subject.instance_variable_get(:@errors)).to eq(['Custom error message in port 443'])
        end
      end
    end

    context 'with proxy' do
      subject { described_class.new.tap { |c| c.add_service(port: 443, host: 'lala.com', proxy: 'http://uriproxy.com.br:8888') } }

      it 'calls Net::Telnet with valid params of proxy' do
        expect(Net::Telnet).to receive(:new).with('Port' => 8888, 'Host' => 'uriproxy.com.br', 'Timeout' => 2).ordered.and_return('proxy')
        expect(Net::Telnet).to receive(:new).with('Port' => 443,  'Host' => 'lala.com',        'Timeout' => 2, 'Proxy' => 'proxy').ordered

        subject.validate
      end

      context 'connection refused' do
        it 'avoid to adds errors array' do
          expect(Net::Telnet).to receive(:new).and_raise Errno::ECONNREFUSED.new
          subject.validate

          expect(subject.instance_variable_get(:@errors)).to be_empty
        end
      end

      context 'timeout' do
        it 'adds timeout to errors array' do
          expect(Net::Telnet).to receive(:new).and_raise Timeout::Error.new
          subject.validate

          expect(subject.instance_variable_get(:@errors)).to eq(['connection refused on: lala.com:443'])
        end
      end
    end
  end
end
