class Invention < ActiveRecord::Base
  belongs_to :creator, class_name: 'Tester', foreign_key: 'creator_id'
end
