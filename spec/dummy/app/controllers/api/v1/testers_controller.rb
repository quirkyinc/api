# encoding: utf-8

require 'quirky-api/controller'
# Tester class for testing.
class Api::V1::TestersController < QuirkyApi::Base
  def index
    respond_with Tester.all
  end

  def errors
  end

  def invalid_request
    tester = Tester.new(name: nil)
    tester.save!
  end

  def as_one
    respond_with Tester.first
  end

  def single_as_arr
    respond_with Tester.where(id: 1).all
  end

  def as_true
    respond_with true
  end

  def as_false
    respond_with false
  end

  def as_nil
    respond_with nil
  end

  def as_hash
    respond_with(
      one: 'two',
      three: 'four'
    )
  end

  def as_arr
    respond_with %w(one two three)
  end

  def as_str
    respond_with 'one'
  end
end
