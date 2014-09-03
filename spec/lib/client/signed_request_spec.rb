describe QuirkyApi::SignedRequest do
  include QuirkyApi::SignedRequest

  describe '#prepare_signed_headers' do
    let(:time) { Time.now.to_i.to_s }
    let(:opts) do
      {
        method: 'GET',
        params: { id: "1", controller: 'clients', action: 'secret', format: 'json' },
        request_url: "http://test.host/clients/1/secret"
      }
    end
    let(:result) { prepare_signed_headers(opts) }

    it 'removes controller, action and format params' do
      expect(result[:params]).to eq(id: "1")
    end

    it 'adds a Timestamp header' do
      expect(result[:headers]['Timestamp']).to eq time
    end

    it 'adds an Authorization header' do
      allow(QuirkyApi::Client).to receive(:api_key).and_return(1)
      expect(result[:headers]['Authorization']).to eq('QuirkyClientAuth 1:' + generate_signed_key(opts))
    end
  end

  describe '#generate_signed_key' do
    let(:opts) do
      {
        method: 'GET',
        params: { id: "1" },
        request_url: "http://test.host/clients/1/secret",
        headers: {
          'Timestamp' => '465861600'
        }
      }
    end
    let(:encoded_string) { "\xF4\xFB\x9B\x95\x90\x91\xAA\xFFn\xC1F\xC2\x97\x89'\xBB\xDBE_o\xF6YH\x92\xCF~\x1F\xBD\x15#\x89\xB4" }
    let(:base64_encoded_string) { '9PublZCRqv9uwUbCl4knu9tFX2/2WUiSz34fvRUjibQ=' }

    before do
      allow(Digest::MD5).to receive(:hexdigest).with('{"id":"1"}').and_return('e405fac593027bc534cf08cd4d2a5647')
      allow(QuirkyApi::Client).to receive(:api_secret).and_return('abc')
      allow(OpenSSL::HMAC).to receive(:digest).and_return(encoded_string)
    end

    it 'generates a canonical string' do
      expect(Digest::MD5).to receive(:hexdigest).with('{"id":"1"}').and_return('e405fac593027bc534cf08cd4d2a5647')
      expect(OpenSSL::HMAC).to receive(:digest).with(OpenSSL::Digest.new('sha256'), 'abc', 'Content-Type:application/json,Method:GET,Content-MD5:ZTQwNWZhYzU5MzAyN2JjNTM0Y2YwOGNkNGQyYTU2NDc=,Request-URI:http://test.host/clients/1/secret,Timestamp:465861600')
      generate_signed_key(opts)
    end

    it 'returns the canonical string, encoded with the client secret' do
      response = generate_signed_key(opts)
      expect(response).to eq base64_encoded_string
    end
  end

  describe '#valid_client_request?' do
    it 'returns false if the expected key and client token are not equal' do
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:generate_signed_key_from_request).and_return('a')
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:client_token).and_return('b')
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:client_request?).and_return(true)

      expect(valid_client_request?).to eq false
    end

    it 'returns true if the expected key does equal the passed token' do
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:generate_signed_key_from_request).and_return('c')
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:client_token).and_return('c')
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:client_request?).and_return(true)

      expect(valid_client_request?).to eq true
    end

    it 'returns nil if it is not a client request.' do
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:client_request?).and_return(false)
      expect(valid_client_request?).to be_nil
    end
  end

  describe '#client_request?' do
    it 'returns true if there is a valid Authorization header' do
      request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth 1:abc' })
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

      expect(client_request?).to eq true
    end

    it 'returns false if there is an Authorization header, but it is bad' do
      request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth :' })
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

      expect(client_request?).to eq false
    end

    it 'returns false if there is no Authorization header' do
      request_dbl = double('request', headers: {})
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

      expect(client_request?).to eq false
    end
  end

  describe '#auth_header' do
    it 'returns a match for a valid client auth header' do
      request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth 1:abc' })
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

      headers = auth_header
      expect(headers[1]).to eq '1'
      expect(headers[2]).to eq 'abc'
    end

    it 'returns nil for an invalid client auth header' do
      request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth :' })
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

      expect(auth_header).to be_nil
    end

    it 'returns nil if there is no client auth header' do
      request_dbl = double('request', headers: {})
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

      expect(auth_header).to be_nil
    end
  end

  describe '#client_secret' do
    context 'if an ENV var exists for the client_id' do
      it 'returns that ENV var as the secret' do
        ENV['CLIENT_1_SECRET'] = 'def'
        request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth 1:abc' })
        allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

        expect(client_secret).to eq 'def'
        ENV.delete('CLIENT_1_SECRET')
      end
    end

    context 'if an ENV var does not exist' do
      it 'sends a request to the auth server for the secret' do
        request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth 1:abc' })
        allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

        allow(HTTParty).to receive(:get).and_return(double('secret_request', success?: true, parsed_response: { 'app_secret' => 'def' }))
        allow(QuirkyApi::Client).to receive(:auth_host).and_return('http://auth-test.local')
        allow(QuirkyApi::Client).to receive(:api_key).and_return(1)

        time = Time.now.to_i
        expected_request_params = {
          method: 'GET',
          params: { id: '1' },
          request_url: 'http://auth-test.local/clients/1/secret',
        }
        expected_request_params.merge!(prepare_signed_headers(expected_request_params))

        expect(HTTParty).to receive(:get).with(
          'http://auth-test.local/clients/1/secret',
          expected_request_params
        )

        sekret = client_secret
      end
    end
  end

  describe '#client_token' do
    it 'returns the client token from the Authorization header' do
      request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth 1:zyx' })
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

      expect(client_token).to eq 'zyx'
    end
  end

  describe '#generate_signed_key_from_request' do
    it 'returns a signed key based on the request' do
      request_dbl = double('request', method: 'GET', params: { id: '99' }, url: 'http://auth-test.local/clients/99/secret', headers: { 'Timestamp' => '465861600', 'Authorization' => 'QuirkyClientAuth 100:xxx' })
      allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)
      ENV['CLIENT_100_SECRET'] = 'zzz'

      expect(generate_signed_key_from_request).to eq 'S5eFRDpC5LcsPVOr5FAuQ/TrHX8tq/d0hZ0kDSBHHrc='
      ENV.delete('CLIENT_100_SECRET')
    end
  end

end
