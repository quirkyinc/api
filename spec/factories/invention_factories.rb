FactoryGirl.define do
  factory :invention do
    sequence(:id) do |n|
      id = (n * 100000) + rand(1..99999)
      until Invention.unscoped.find_by_id(id).nil?
        id = (n * 100000) + rand(1..99999)
      end
      id
    end

    creator { FactoryGirl.create(:tester) }
  end
end


