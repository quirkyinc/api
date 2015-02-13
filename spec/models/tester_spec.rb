require File.expand_path('../../spec_helper', __FILE__)

describe Tester do
  subject { FactoryGirl.create(:tester) }

  it 'responds to name' do
    expect(subject).to respond_to(:name)
  end

  it 'has many inventions' do
    tester = Tester.create(name: 'oren')
    invention = Invention.create(creator: tester)
    tester.reload
    invention.reload
    expect(invention.creator).to eq tester
    expect(tester.inventions).to include invention
  end
end
