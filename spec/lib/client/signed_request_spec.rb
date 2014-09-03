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
        ENV['1_secret'] = 'def'
        request_dbl = double('request', headers: { 'Authorization' => 'QuirkyClientAuth 1:abc' })
        allow_any_instance_of(QuirkyApi::SignedRequest).to receive(:request).and_return(request_dbl)

        expect(client_secret).to eq 'def'
      end
    end

    context 'if an ENV var does not exist' do
      it 'sends a request to the auth server for the secret' do
        ENV.delete('1_secret')

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
end
# describe QuirkyApi::Request do
#   include QuirkyApi::Request
#   require 'quirky-api/client/user'

#   describe 'request type methods' do
#     before do
#       allow_any_instance_of(QuirkyApi::Request).to receive(:request).and_return(true)
#     end

#     describe '#get' do
#       it 'initiates a GET request' do
#         expect_any_instance_of(Object).to receive(:request).with(:get, '/', {}).and_return(true)
#         get '/'
#       end
#     end

#     describe '#post' do
#       it 'initiates a POST request' do
#         expect_any_instance_of(Object).to receive(:request).with(:post, '/users/create', { params: { name: 'Bob' } }).and_return(true)
#         post '/users/create', { params: { name: 'Bob' } }
#       end
#     end

#     describe '#put' do
#       it 'initiates a PUT request' do
#         expect_any_instance_of(Object).to receive(:request).with(:put, '/1', { params: { name: 'Jim' } }).and_return(true)
#         put '/1', { params: { name: 'Jim' } }
#       end
#     end

#     describe '#delete' do
#       it 'initiates a DELETE request' do
#         expect_any_instance_of(Object).to receive(:request).with(:delete, '/2', {}).and_return(true)
#         delete '/2'
#       end
#     end
#   end

#   describe '#request' do
#     it 'makes and parses a request' do
#       allow_any_instance_of(QuirkyApi::Request).to receive(:build_opts).with(:get, '/auth', params: { email: 'test@example.com', pass: 'testing123' }).and_return(host: 'blah.com')
#       r = double(:r, run: 'test')
#       allow_any_instance_of(QuirkyApi::Request).to receive(:make_request).with(:get, host: 'blah.com').and_return(r)
#       allow_any_instance_of(QuirkyApi::Request).to receive(:parse_request).with('test').and_return(true)

#       expect_any_instance_of(Object).to receive(:build_opts).with(:get, '/auth', { params: { email: 'test@example.com', pass: 'testing123' } }).and_return(host: 'blah.com')
#       expect_any_instance_of(Object).to receive(:make_request).with(:get, { host: 'blah.com' }).and_return('test')
#       expect_any_instance_of(Object).to receive(:parse_request).with('test').and_return(true)

#       request :get, '/auth', params: { email: 'test@example.com', pass: 'testing123' }
#     end
#   end

#   describe '#build_opts' do
#     before do
#       allow_any_instance_of(Object).to receive(:host).and_return('qc')
#       allow_any_instance_of(Object).to receive(:endpoint).and_return('/api/v2/users')
#       allow(QuirkyApi::Client).to receive(:qc_host).and_return('http://test.local')
#     end

#     context 'host' do
#       it 'generates a host if has not been presented' do
#         expect(QuirkyApi::Client).to receive(:qc_host).and_return('http://test.local')
#         opts = build_opts :get, '/auth', {}
#         expect(opts[:host]).to eq 'http://test.local'
#       end

#       it 'lets you assign a host' do
#         expect(QuirkyApi::Client).to_not receive(:qc_host)
#         opts = build_opts :get, '/auth', host: 'http://banana.local'
#         expect(opts[:host]).to eq 'http://banana.local'
#       end

#       it 'raises an error if there is no host' do
#         allow(QuirkyApi::Client).to receive(:qc_host).and_return(nil)
#         expect { build_opts :get, '/bad', {} }.to raise_error(InvalidRequest)
#       end
#     end

#     context 'endpoint' do
#       it 'generates an endpoint if one does not exist' do
#         opts = build_opts :get, '/me', {}
#         expect(opts[:endpoint]).to eq '/api/v2/users/me'
#       end

#       it 'lets you assign an endpoint' do
#         opts = build_opts :get, '/me', endpoint: '/me'
#         expect(opts[:endpoint]).to eq '/me'
#       end

#       it 'raises an error if there is no endpoint' do
#         allow_any_instance_of(Object).to receive(:endpoint).and_return('')
#         allow(QuirkyApi::Client).to receive(:qc_host).and_return(nil)
#         expect { build_opts :get, '', {} }.to raise_error(InvalidRequest)
#       end
#     end

#     it 'generates a request_url if one does not exist' do
#       opts = build_opts :get, '/quirky', {}
#       expect(opts[:request_url]).to eq 'http://test.local/api/v2/users/quirky'
#     end

#     it 'lets you assign a request url' do
#       opts = build_opts :get, '/quirky', request_url: 'http://www.google.com'
#       expect(opts[:request_url]).to eq 'http://www.google.com'
#     end
#   end

#   describe '#make_request' do
#     before do
#       allow(Typhoeus::Request).to receive(:new).and_return(double(:req, run: true))
#     end

#     it 'honors the request method' do
#       expect(Typhoeus::Request).to receive(:new).with(
#         'http://www.google.com',
#         {
#           method: :get,
#           body: {}.to_json,
#           headers: {
#             'X-Api-Client-Version' => QuirkyApi::Client::VERSION,
#             'Content-Type'=>'application/json',
#             'Accept'=>'application/json'
#           }
#         }
#       )
#       make_request :get, request_url: 'http://www.google.com'
#     end

#     it 'honors params' do
#       expect(Typhoeus::Request).to receive(:new).with(
#         'http://www.google.com',
#         {
#           method: :get,
#           body: {
#             name: 'Mike'
#           }.to_json,
#           headers: {
#             'X-Api-Client-Version' => QuirkyApi::Client::VERSION,
#             'Content-Type'=>'application/json',
#             'Accept'=>'application/json'
#           }
#         }
#       )
#       make_request :get, request_url: 'http://www.google.com', params: { name: 'Mike' }
#     end

#     it 'honors headers' do
#       expect(Typhoeus::Request).to receive(:new).with(
#         'http://www.google.com',
#         {
#           method: :get,
#           body: {}.to_json,
#           headers: {
#             'X-Api-Client-Version' => QuirkyApi::Client::VERSION,
#             'Content-Type'=>'application/json',
#             'Accept'=>'application/json',
#             'X-App-Version' => '1.0.1'
#           }
#         }
#       )
#       make_request :get, request_url: 'http://www.google.com', headers: { 'X-App-Version' => '1.0.1' }
#     end

#     it 'honors body' do
#       expect(Typhoeus::Request).to receive(:new).with(
#         'http://www.google.com',
#         {
#           method: :get,
#           body: {}.to_json,
#           headers: {
#             'X-Api-Client-Version' => QuirkyApi::Client::VERSION,
#             'Content-Type'=>'application/json',
#             'Accept'=>'application/json'
#           }
#         }
#       )
#       make_request :get, request_url: 'http://www.google.com'
#     end
#   end

#   describe '#default_headers' do
#     before do
#       allow(QuirkyApi::Client).to receive(:api_key).and_return('abcdefg')
#       stub_const('QuirkyApi::Client::VERSION', '1.2.3')
#     end

#     it 'returns a auth header and version header' do
#       expect(default_headers).to eq({
#         'X-Api-Client-Version' => '1.2.3',
#         'Content-Type'=>'application/json',
#         'Accept'=>'application/json',
#       })
#     end

#     it 'honors initial headers' do
#       allow(QuirkyApi::Client).to receive(:initial_headers).and_return({
#         'X-First-Name' => 'Mike'
#       })

#       expect(default_headers).to eq({
#         'X-Api-Client-Version' => '1.2.3',
#         'Content-Type'=>'application/json',
#         'Accept'=>'application/json',
#         'X-First-Name' => 'Mike'
#       })
#     end
#   end

#   describe '#parse_request' do
#     it 'parses data and assigns it to a class' do
#       res = double(:r, body: '{"data":{"name":"Test User","email":"test@example.com","blah":"asdf"}', success?: true)

#       banana = QuirkyApi::User.new
#       response = banana.send(:parse_request, res)
#       expect(response).to be_an_instance_of QuirkyApi::User
#       expect(response.name).to eq 'Test User'
#       expect(response.email).to eq 'test@example.com'
#       expect { response.blah }.to raise_error LoadError

#       expect(response.success?).to eq true
#     end

#     it 'parses an array and returns an array of classes' do
#       res = double(:r, body: '{"data":[{"id":1,"name":"Test User","email":"test@example.com","blah":"asdf"},{"id":2,"name":"Test User","email":"test@example.com","blah":"asdf"}]}', success?: true)

#       banana = QuirkyApi::User.new
#       response = banana.send(:parse_request, res)
#       expect(response).to be_an_instance_of Array
#       expect(response.length).to eq 2

#       response.each do |item|
#         expect(item).to be_an_instance_of QuirkyApi::User
#         expect(item.name).to eq 'Test User'
#         expect(item.email).to eq 'test@example.com'
#         expect { item.blah }.to raise_error LoadError
#       end

#       expect(response.success?).to eq true
#     end

#     it 'returns false for success? if it failed' do
#       res = double(:r, body: '{"data":{"name":"Test User","email":"test@example.com","blah":"asdf"}', success?: false)

#       banana = QuirkyApi::User.new
#       response = banana.send(:parse_request, res)
#       expect(response).to be_an_instance_of QuirkyApi::User
#       expect(response.name).to eq 'Test User'
#       expect(response.email).to eq 'test@example.com'
#       expect { response.blah }.to raise_error LoadError

#       expect(response.success?).to eq false
#     end

#     it 'returns errors if there are any' do
#       res = double(:r, body: '{"errors": "Fail"}', success?: false)
#       banana = QuirkyApi::User.new
#       response = banana.send(:parse_request, res)
#       expect(response).to_not be_an_instance_of QuirkyApi::User
#       expect(response).to eq({ 'errors' => 'Fail' })
#       expect(response.success?).to eq false
#     end
#   end
# end
