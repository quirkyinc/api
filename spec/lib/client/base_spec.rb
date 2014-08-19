describe QuirkyApi::Client do
  it 'is configurable' do
    expect(QuirkyApi::Client).to receive(:configure).with(api_key: 'abcd').and_return an_instance_of QuirkyApi::Client
    QuirkyApi::Client.new(api_key: 'abcd')
  end

  it 'associates missing methods with lib classes' do
    client = QuirkyApi::Client.new(api_key: 'abcd')
    expect(client.users).to be_an_instance_of QuirkyApi::User
  end

  it 'raises an error on a method that truly does not exist' do
    client = QuirkyApi::Client.new(api_key: 'abcd')
    expect { client.abcdefg }.to raise_error(LoadError)
  end
end
