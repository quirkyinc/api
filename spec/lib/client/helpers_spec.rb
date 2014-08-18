describe QuirkyApi::ClientHelpers do
  # Needed due to uninitialized constants.
  require 'quirky-api/client/user'

  let(:client) { QuirkyApi::Client.new(api_key: 'abc', qc_host: 'http://test.local') }

  describe '#list' do
    it 'requests the index endpoint' do
      allow_any_instance_of(QuirkyApi::User).to receive(:get).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:get).with('/', {}).and_return(true)

      client.users.list
    end
  end

  describe '#find' do
    it 'errors if you do not specify an id.' do
      expect { client.users.find(nil) }.to raise_error(InvalidRequest)
    end

    it 'requests the show endpoint' do
      allow_any_instance_of(QuirkyApi::User).to receive(:get).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:get).with('/1', {}).and_return(true)

      client.users.find(1)
    end
  end

  describe '#create' do
    it 'errors if you do not specify params' do
      expect { client.users.create(nil) }.to raise_error(InvalidRequest)
      expect { client.users.create({}) }.to raise_error(InvalidRequest)
      expect { client.users.create({body: 'hi'}) }.to raise_error(InvalidRequest)
    end

    it 'sends a post request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:post).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:post).with('/', params: { email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine' }).and_return(true)

      client.users.create(params: { email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine' })
    end
  end

  describe '#update' do
    it 'errors if you do not specify an id' do
      expect { client.users.update(nil, { params: { email: 'test@example.com' }}) }.to raise_error(InvalidRequest)
    end

    it 'errors if you do not specify params' do
      expect { client.users.update(1, nil) }.to raise_error(InvalidRequest)
      expect { client.users.update(1, {}) }.to raise_error(InvalidRequest)
      expect { client.users.update(1, {body: 'hi'}) }.to raise_error(InvalidRequest)
    end

    it 'sends a put request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:put).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:put).with('/1', params: { email: 'test@example.com' }).and_return(true)

      client.users.update(1, params: { email: 'test@example.com' })
    end
  end

  describe '#destroy' do
    it 'errors if you do not specify an id' do
      expect { client.users.destroy(nil) }.to raise_error(InvalidRequest)
    end

    it 'sends a put request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:delete).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:delete).with('/1', {}).and_return(true)

      client.users.destroy(1)
    end
  end
end
