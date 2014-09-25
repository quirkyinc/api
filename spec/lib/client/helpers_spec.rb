describe QuirkyApi::ClientHelpers do
  # Needed due to uninitialized constants.
  require 'quirky-api/client/user'

  let(:client) { QuirkyApi::Client.new(api_key: 'abc', qc_host: 'http://test.local') }

  describe '#list' do
    it 'requests the index endpoint' do
      res = double(:response, failure?: false)

      allow_any_instance_of(QuirkyApi::User).to receive(:get).and_return res
      expect_any_instance_of(QuirkyApi::User).to receive(:get).with('/', params: {}).and_return(res)

      client.users.list
    end

    it 'throws an error if there was an error with the request' do
      res = double(:response, failure?: true, code: 404, errors: 'Not found.')

      allow_any_instance_of(QuirkyApi::User).to receive(:get).and_return res
      expect_any_instance_of(QuirkyApi::User).to receive(:get).with('/', params: {}).and_return(res)

      expect { client.users.list }.to raise_error(QuirkyApi::Request::NotFound)
    end
  end

  describe '#find' do
    it 'errors if you do not specify an id.' do
      expect { client.users.find(nil) }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'requests the show endpoint' do
      res = double(:response, failure?: false)
      allow_any_instance_of(QuirkyApi::User).to receive(:get).and_return(res)
      expect_any_instance_of(QuirkyApi::User).to receive(:get).with('/1', params: {:id => "1"}).and_return(res)

      client.users.find(1)
    end

    it 'throws an error if there was an error with the request' do
      res = double(:response, failure?: true, code: 404, errors: 'Not found.')

      allow_any_instance_of(QuirkyApi::User).to receive(:get).and_return(res)
      expect_any_instance_of(QuirkyApi::User).to receive(:get).with('/1', params: {:id => "1"}).and_return(res)

      expect { client.users.find(1) }.to raise_error(QuirkyApi::Request::NotFound)
    end
  end

  describe '#create' do
    it 'errors if you do not specify params' do
      expect { client.users.create(nil) }.to raise_error(QuirkyApi::Request::InvalidRequest)
      expect { client.users.create({}) }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'sends a post request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:post).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:post).with('/', params: { email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine' }).and_return(true)

      client.users.create(email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine')
    end
  end

  describe '#create!' do
    it 'errors if you do not specify params' do
      expect { client.users.create(nil) }.to raise_error(QuirkyApi::Request::InvalidRequest)
      expect { client.users.create({}) }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'sends a post request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:post).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:post).with('/', params: { email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine' }).and_return(true)

      client.users.create(email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine')
    end

    it 'throws an error if there was an error with the request' do
      res = double(:response, failure?: true, code: 401, errors: 'Not Authorized.')

      allow_any_instance_of(QuirkyApi::User).to receive(:post).and_return res
      expect_any_instance_of(QuirkyApi::User).to receive(:post).with('/', params: { email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine' }).and_return(res)

      expect { client.users.create!(email: 'user@example.com', first_name: 'Bob', last_name: 'Mctestinstine') }.to raise_error(QuirkyApi::Request::Unauthorized)
    end
  end

  describe '#update' do
    it 'errors if you do not specify an id' do
      expect { client.users.update(nil, email: 'test@example.com') }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'errors if you do not specify params' do
      expect { client.users.update(1, nil) }.to raise_error(QuirkyApi::Request::InvalidRequest)
      expect { client.users.update(1, {}) }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'sends a put request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:put).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:put).with('/1', params: { email: 'test@example.com', id: '1' }).and_return(true)

      client.users.update(1, email: 'test@example.com')
    end
  end

  describe '#update!' do
    it 'errors if you do not specify an id' do
      expect { client.users.update(nil, email: 'test@example.com') }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'errors if you do not specify params' do
      expect { client.users.update(1, nil) }.to raise_error(QuirkyApi::Request::InvalidRequest)
      expect { client.users.update(1, {}) }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'sends a put request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:put).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:put).with('/1', params: { email: 'test@example.com', id: '1' }).and_return(true)

      client.users.update(1, email: 'test@example.com')
    end

    it 'throws an error if there was an error with the request' do
      res = double(:response, failure?: true, code: 400, errors: 'Title missing.')

      allow_any_instance_of(QuirkyApi::User).to receive(:put).and_return res
      expect_any_instance_of(QuirkyApi::User).to receive(:put).with('/1', params: { email: 'test@example.com', id: '1' }).and_return(res)

      expect { client.users.update!(1, email: 'test@example.com') }.to raise_error(QuirkyApi::Request::BadRequest)
    end
  end

  describe '#destroy' do
    it 'errors if you do not specify an id' do
      expect { client.users.destroy(nil) }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'sends a put request' do
      allow_any_instance_of(QuirkyApi::User).to receive(:delete).and_return true
      expect_any_instance_of(QuirkyApi::User).to receive(:delete).with('/1', params: { id: '1' }).and_return(true)

      client.users.destroy(1)
    end
  end

  describe '#destroy!' do
    it 'errors if you do not specify an id' do
      expect { client.users.destroy(nil) }.to raise_error(QuirkyApi::Request::InvalidRequest)
    end

    it 'sends a put request' do
      res = double(:response, failure?: true, code: 500, errors: 'Title missing.')

      allow_any_instance_of(QuirkyApi::User).to receive(:delete).and_return res
      expect_any_instance_of(QuirkyApi::User).to receive(:delete).with('/1', params: { id: '1' }).and_return(res)

      expect { client.users.destroy!(1) }.to raise_error(QuirkyApi::Request::ServerError)
    end
  end
end
