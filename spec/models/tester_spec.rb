require File.expand_path('../../spec_helper', __FILE__)

describe Tester do
  subject { FactoryGirl.create(:tester) }

  it 'responds to name' do
    expect(subject).to respond_to(:name)
  end
end
