# encoding: utf-8

class PostSerializer < QuirkySerializer
  attributes :id, :title, :blurb
  optional :joke
  associations :myself

  verify_permissions :title do
    true
  end

  def joke
    'Why was six afraid of seven?'
  end

  def myself
    object
  end
end
