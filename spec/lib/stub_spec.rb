require 'spec_helper'

describe QuirkyApi do
  context 'when stubbing' do
    before do
      allow(QuirkyApi).to receive(:disable_stubs).and_return(false)
      allow(QuirkyApi::Client).to receive(:qc_host).and_return('http://localhost:8888')
      require 'quirky-api/stub'
    end

    let(:client) { QuirkyApi::Client.new(qc_host: 'http://localhost:8888', qtip_host: 'http://localhost:3000') }

    it 'should stub a user find call for user 1' do
      user = client.users.find(1)
      expect(user.email).to eq('admin@quirky.com')
    end

    it 'should stub a user find call for user 2' do
      user = client.users.find(2)
      expect(user.email).to eq('user@quirky.com')
    end

    it 'should stub a valid user create call with a successful request' do
      user = client.users.create(email: 'cbrady@quirky.com', first_name: 'Chris', last_name: 'Brady', password: 'password')
      expect(user).to be_a(QuirkyApi::User)
    end

    it 'should stub an invalid user create call with an error response' do
      expect { client.users.create({}) }.to raise_error
    end
  end
end
