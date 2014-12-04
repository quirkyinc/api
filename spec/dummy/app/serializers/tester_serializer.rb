# encoding: utf-8

class TesterSerializer < QuirkySerializer
  attributes :id, :name
  optional :last_name
  associations :product, :post
  default_associations :product

  def last_name
    object.last_name
  end

  def product
    Product.all
  end

  def post
    Post.last
  end
end
