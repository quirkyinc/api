FactoryGirl.define do
  factory :tester do
    name 'Mike'
  end
  factory :post do
    title "Hi"
    blurb "What's up?"
  end
  factory :random_post, class: Post do
    title { Faker::Lorem.words(3).join(' ') }
    blurb { Faker::Lorem.paragraph }
  end
  factory :product do
    name "blah"
    desc "so on"
  end
end

