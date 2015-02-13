class Tester < ActiveRecord::Base
  has_many :inventions, foreign_key: 'creator_id'
  validates_presence_of :name
end
