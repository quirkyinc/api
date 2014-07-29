FactoryGirl.define do
  factory :tester do
    name 'Mike'
  end
  factory :post do
    title "Hi"
    blurb "What's up?"
  end
  factory :product do
    name "blah"
    desc "so on"
  end
end

