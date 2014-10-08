# Quirky API

- [Explanation](#explanation)
- [Usage](#usage)
- [Rendering content](#rendering)
  - [Caveats](#response-caveats)
  - [Changing response status code](#changing-response-status-code)
  - [Top level elements](#top-level-elements)
- [`respond_with` second parameter options](#respond_with-second-parameter-options)
  - [status](#respond_with-second-parameter-options)
  - [associations](#respond_with-second-parameter-options)
  - [extra_fields](#respond_with-second-parameter-options)
  - [only](#respond_with-second-parameter-options)
  - [exclude](#respond_with-second-parameter-options)
  - [elements](#respond_with-second-parameter-options)
- [Serializers](#serializers)
  - [Attributes](#attributes)
  - [Optional fields](#optional-fields)
  - [Associations](#associations)
    - [Association filtering](#association-filtering)
  - [Caching data](#caching-data)
- [Serializing data](#serializing-data)
  - [`serialize` helper method](#serialize-helper-method)
  - [Manual serialization](#manual-serialization)
  - [Array serialization](#array-serialization)
- [QuirkyApi::Client](#quirkyapiclient)
  - [Explanation](#client-explanation)
  - [Usage](#client-usage)
    - [Available helpers](#available-helpers)
    - [Custom request methods](#custom-request-methods)
  - [Security](#security)
  - [Client models](#client-models)
    - [`api_host`](#api_host)
    - [`api_endpoint`](#api_endpoint)
    - [Virtus model](#virtus-model)

## Explanation

The `quirky-api` gem provides a library of useful tools and methods to help make API development easier.  It also provides a client that interacts with the actual Quirky API.

All functionality is automatically included by adding `quirky-api` to your Gemfile:

```ruby
gem 'quirky-api'
```

## Usage

API controllers may be namespaced however you wish, but should always inherit from `QuirkyApi::Base`.  `QuirkyApi::Base` provides the helper methods and performance improvements essential to the API.

```ruby
module Api
  module V1
    class UsersController < QuirkyApi::Base
      def index
        respond_with User.all
      end
    end
  end
end
```

## Rendering content

Use `respond_with` to render content in the API.  `respond_with`, in the scope of `quirky-api`, is an abstraction that provides better integration with Active Model Serializers.  It also provides a [TODO number of options](#options) that make responding with dynamic content easier.

```ruby
module Api
  module V1
    class UsersController < QuirkyApi::Base
      def index
        respond_with User.paginate(page: 1 || params[:page], per_page: 15 || params[:per_page])
      end
    end
  end
end
```

`respond_with` always outputs content as JSON.  Objects are subsequently wrapped inside a `data` key, as below:

```json
{
  "data": [
    {
      "id": 1,
      "name": "Mike",
      "last_name": "Sea"
    },
    {
      "id": 2,
      "name": "Bob",
      "last_name": "McTestinstine"
    }
  ]
}
```

### Response caveats:

* If the content passed to `respond_with` is an array (of any type), regardless of the number of elements in said array, `respond_with` will return that content wrapped in an array, as above.

* If you pass a single object to `respond_with`, data will be presented as a single hash, as below:

  ```ruby
  respond_with User.first
  ```
  ```json
  {
    "data": {
      "id": 1,
      "name": "Mike",
      "last_name": "Sea"
    }
  }
  ```
* If you pass a boolean value, a string, or nil, the output will still contain the `data` key, but the value will only be the literal that you passed:

  ```ruby
  respond_with true # or false, or nil, or 'toast'....
  ```
  ```json
  {
    "data": true
  }
  ```
* If you pass a hash, you *must* surround your hash with parenthesis.  `respond_with` will intentionally not serialize any values of a hash.  Once again, `respond_with` WILL INTENTIONALLY NOT SERIALIZE ANY VALUES OF A HASH.  If you wish to serialize something, serialize it yourself with the `serialize` helper method:

  ```ruby
  respond_with({
    bool: true,
    user_id: 1,
    user: serialize(User.first),
    followers: serialize(User.first.followers)
  })
  ```
  ```json
  {
    "data": {
      "bool": true,
      "user_id": 1,
      "user": {
        "id": 1,
        "name": "Mike",
        "last_name": "Sea"
      },
      "followers": [
        {
          "id": 1,
          "follower_id": 100,
        },
        {
          "id": 2,
          "follower_id": 101,
        },
      ]
    }
  }
  ```
* If there are errors in the execution of the endpoint, `respond_with` will return a JSON hash with an "errors" key, along with the associated errors.

  ```ruby
  @user = User.find(9999999999)
  respond_with @user
  ```
  ```json
  {
    "errors": "Not found."
  }
  ```

### Changing response status code

`respond_with` also accepts an optional `status` option, as a second parameter.  The `status` option will specify the status code that the response should return.

```ruby
@user = User.create!(...)
respond_with @user, status: 201 # Or any other valid status code
```

### Top level elements

`respond_with` also accepts an optional `elements` option, as a second parameter.  `elements` will let you specify top-level keys for the JSON output.  The value should be a hash.

```ruby
respond_with User.first, elements: { status: 'success' }
```
```json
{
  "data": {
    "id": 1,
    "name": "Mike",
    "last_name": "Sea"
  },
  "status": "success"
}
```

Both `elements` and `status` may be combined.

## `respond_with` second parameter options

Here are all of the available second parameter options to `respond_with`.  All are optional and may be used in tandem:

- `status` will change the status of the response.  This must be a valid status code.

  ```ruby
  respond_with @user, status: 201
  ```

- `associations` must be an array and will automatically include the specified associations in the response.

  ```ruby
  respond_with @user, associations: [:profile]
  ```

- `extra_fields` must be an array and will automatically include the specified optional fields in the response.

  ```ruby
  respond_with @user, extra_fields: [:town, :favorite_color]
  ```

- `only` must be an array and will return *only* the specified fields.

  ```ruby
  respond_with @user, only: [:id, :name]
  ```

- `exclude` must be an array and will *exclude* the specified fields from the request.

  ```ruby
  respond_with @user, exclude: [:last_name]
  ```

- `elements` allows you to set root-level keys and their values.  These will *not* fall under the `data` key.

  ```ruby
  respond_with @user, elementes: { status: 'success' }
  ```

All of the above may be combined, mixed and matched, or not used at all.

## Serializers

The Quirky API gem exposes a slightly altered instance of ActiveModel Serializers.  AMS serializes an object and returns only what you want to return.

Serializers should be placed in the `app/serializers` directory, and be named `model_name_serializer.rb` where `model_name` is `object.class.underscore`.  Serializers should have this structure:

```ruby
class ModelNameSerializer < QuirkySerializer
  attributes :id, :name, :last_name, :fav_animal
  optional :town, :age
  associations :profile, :avatar

  def fav_animal
    # This overrides the value of object.fav_animal and always returns 'Giraffe'.
    'Giraffe'
  end

  def age
    # Use object to reference the model.
    if object.age > 20 && object.age < 50
      'Young'
    elsif object.age > 50
      'Old'
    else
      'Really young'
    end
  end
end
```


### Attributes

```ruby
attributes :id, :name, :last_name
```

This will specify what attributes will appear by default when serializing content with this serializer.  The value of an attribute is determined like so:

1. If the serializer has a method of the same name as an attribute, the serializer will return the value of that method.

   ```ruby
   # UserSerializer
   attribute :id, :name, :fav_animal

   # ...

   def fav_animal
     'Zebra'
   end

   # The serialized value will always be 'Zebra'.
   ```
2. If the serializer does not have a method / association of the same name as an attribute, but the model does, the serializer will return the value of the method called on the model.

   ```ruby
   # UserSerializer
   attribute :id, :name, :fav_animal

   # User model

   def fav_animal
     if real_life?
       'Giraffe'
     else
       'Taun Taun'
     end
   end

   # The serialized value of fav_animal will be either 'Giraffe' or 'Taun Taun', depending on the value of real_life?
   ```

3. If neither the serializer nor the model have a method / association of the same name as an attribute, a `NameError` will be thrown.

By default, attributes are not serialized.  If you want an attribute serialized, use the `serialize` helper method or make that attribute an association.

### Optional fields

```ruby
optional :town, :age
```

The only difference between optional fields and attributes is that optional fields do not show up by default.  Optional fields need to be requested either in the request itself, or on the endpoint with `respond_with`:

```
GET api/v1/users?extra_fields=town,age
```

Or...

```ruby
respond_with User.all, extra_fields: [:town, :age]
```

Everything else about optional fields behaves like attributes.  Optional fields are not serialized by default.  If you wish to serialize an optional field, use the `serialize` helper method or make that optional field an association.

### Associations

```ruby
associations :profile, :avatar
```

Associations are similar to attributes, but they *are* serialized based on the class of the associated object.

Retrieving the associated object on an object behaves much the same way as an attribute:

1. Check the serializer
2. Check the model
3. Fail

Once the serializer has the associated object, it attempts to find a serializer for that object and serialize it.  The value of the attribute in the original response, then, will be the serialized sub-object.

As an example, say we were serializing a User object.  The UserSerializer looks like this:

```ruby
class UserSerializer
  attributes :id, :first, :last
  associations :profile
end
```

We retrieve the profile from the user model by calling `user.profile`.  Since the profile, in turn, is an instance of the `Profile` class, it will be serialized with the `ProfileSerializer`:

```ruby
class ProfileSerializer
  attributes :bio, :town, :skills
end
```

So the complete response will look like this:

```json
{
  "data": {
    "id": 1,
    "first": "Test",
    "last": "User",
    "profile": {
      "bio": "I'm a test user",
      "town": "NYC",
      "skills": "Testing, Driving"
    }
  }
}
```

Associations do not show up by default.  They need to be requested either in the request itself, or on the endpoint with `respond_with`:

```
GET api/v1/users?associations=profile,avatar
```

Or...

```ruby
respond_with User.all, associations: [:profile, :avatar]
```

### Association filtering

Meta-filtering is possible, only for associations, due to the fact that they are serialized inside of a serialized object.  In the same way that you would request field inclusion or exclusion, optional fields and / or associations, you may do so on associations themself, by prefixing the association name to `_fields`, `_extra_fields` or `_associations`.

```ruby
respond_with User.all, associations: [:profile], profile_fields: [:town, :bio], profile_associations: [:avatar]
```

## Caching data

Caching is a very complicated topic in serialization, given serialized data often changes.  That said, there is a helper on every serializer called `caches` that attemps to aleviate some of that pain.

`caches` works by rendering an object, and along the way caching every single attribute on that object (instead of the entire object at once).  This makes processing significantly faster on subsequent serialization.  The caching works like this:

```ruby
Rails.cache.fetch [object, field] do
  get_value(field)
end
```

This in turns uses the object's `cache_key` in order to generate the cache token.  Unless overridden, a typical cache key is `object_class_name-object_id/updated_at.to_i`.  Therefore, but touching the object at an time, you effectively bust the cache for that serialized object.

`caches` takes a number of possible values, which may be used together or not at all:

- `:all` will cache every attribute, optional field and association.
- `:fields` will cache only attributes.
- `:optional_fields` will cache only optional fields.
- `:associations` will cache only associations.
- `:field_name` will cache just that field.

Example uses:

```ruby
# Caches everything
caches :all

# Caches only fields and associations
caches :fields, :associations

# Caches the 'email' field and the 'profile' association, but nothing else
caches :email, :profile
```

## Serializing data

Data is serialized for response by way of the serializers described above.  By default, `respond_with` performs the serialization for you, but in the case that you want to serialize an object yourself, you still can.

### `serialize` helper method

The `serialize` helper method makes it easy to serialize any object or array of objects.  Simple call `serialize(object)`:

```ruby
serialize(User.first)
```

`serialize` also accepts two optional parameters:

1. the optional second parameter is the serializer to use to serialize that object.  If it is nil, the method will figure out the serializer for you.
2. the optional third parameter is any options to pass to the serializer.  You may use any of the [second parameter options for `respond_with`](#respond_with-second-parameter-options), in this parameter.

The `serialize` method also automatically sends `current_user` and `params` to every serializer, so that those values may be used inside the serializer.  You do not need to do anything for those helpers to be sent.

Examples:

```ruby
# Serializes the first user with UserSerializer
serialize(User.first)

# Serializes the first user with SpecialUserSerializer
serialize(User.first, SpecialUserSerializer)

# Serializes the first user and asks only for their first name and their profile
serialize(User.first, nil, only: [:first_name], associations: [:profile])
```

### Manual serialization

Say you wanted to serialize a single user:

```ruby
@user = UserSerializer.new(User.first).as_json(root: false)
```

Notice that we use `as_json` to return a Ruby hash of the serialized data.  You may also use `to_json` to return a JSON string.

Individual serializers also accept optional second parameters in exactly the same way that `respond_with` does.  This will allow you to request associations or optional fields, or even ask for specific fields.

```ruby
@user = UserSerializer.new(User.first, associations: [:profile], extra_fields: [:town]).as_json(root: false)
```

If you wish to ask for only specific fields, use the `only` parameter:

```ruby
@user = UserSerializer.new(User.first, only: [:id, :name]).as_json(root: false)
```

### Array serialization

If you wish to serialize an array of objects, use `QuirkyArraySerializer`.

```ruby
@user = QuirkyArraySerializer.new(User.all).as_json(root: false)
```

The same options that apply to object serialization apply to `QuirkyArraySerializer`.  `QuirkyArraySerializer` will attempt to find a serializer for every item in the array, and serialize that item with that serializer and with any options passed as the second parameter.

```ruby
@user = QuirkyArraySerializer.new(User.all, only: [:id, :name]).as_json(root: false)
```

# QuirkyApi::Client

## Client explanation

The `QuirkyApi::Client` is a library that communicates with Quirky APIs across each applications.  It generates secure, signed requests and handles responses with pseudo models.

`QuirkyApi::Client` is automatically available with the `quirky-api` gem.

## Client Usage

Instantiate the `QuirkyApi::Client` class and make a request for a particular model:

```ruby
client = QuirkyApi::Client.new
client.users.find(1) # Will make a request to fetch user 1.
```

The model name should always be lowercase and pluralized.  Good examples are: `users`, `products`, `inventions`.

### Available helpers

There are several helpers available in typical client requests:

- `model.list` (`GET #{api_endpoint}`) will hit the "index" endpoint, which should return an array of (model)s.
- `model.find(ID)` (`GET #{api_endpoint}/#{ID}`) will find a single (model) based on the specified ID.
- `model.find_batches([IDS])` (`GET #{api_endpoint}/#{IDS.join(',')}`) will find several (models) that have IDs that match (IDS).
- `model.create(ATTRS)` (`POST #{api_endpoint}`) will attempt to create an instance of (model).
- `model.create!(ATTRS)` (`POST #{api_endpoint}`) will attempt to create an instance of (model).  It will raise errors if something goes wrong.
- `model.update(ID, ATTRS)` (`PUT #{api_endpoint}/#{ID}`) will update the (model) specified by (ID), passing (ATTRS).
- `model.update!(ID, ATTRS)` (`PUT #{api_endpoint}/#{ID}`) will update the (model) specified by (ID), passing (ATTRS).  It will raise errors if something goes wrong.
- `model.destroy(ID)` (`DELETE #{api_endpoint}/#{ID}`) will delete the (model) specified by (ID).
- `model.destroy!(ID)` (`DELETE #{api_endpoint}/#{ID}`) will delete the (model) specified by (ID).  It will raise errors if something goes wrong.

**Note**: You may pass custom parameters to any of these helpers as a first parameter (for `list` and `create`) or a second parameter (for `find`, `find_batches,`, `update`, `destroy`).  Parameters may be passed like so:

```ruby
client = QuirkyApi::Client.new
client.users.list(per_page: 10)
```

### Custom request methods

`QuirkyApi::Client` also provides `get`, `post`, `put` and `delete` helpers.  In API models, you can create custom request methods with those helpers to do unique operations outside of the "available helpers" described above:

```ruby
class QuirkyApi::User < Client
  # ...
  def authenticate(username, password)
    post '/authenticate', params: { username: username, password: password }
  end
end
```

Notice the simple execution of this.  Parsing happens automatically.  Note that you must pass params as a hash under a `params` key.

The above custom method would be used like this:

```ruby
client = QuirkyApi::Client.new
client.users.authenticate('test@example.com', 'pass123')
```

Response parsing happens automatically.  The result of the above would request would be an instance of `QuirkyApi::User`.

## Security

`QuirkyApi::Client` signs requests with the app-specific client secret before making the actaul request.  When a request is received and recognized as a client request (which happens automatically), the receiving server generates a signed string from the request it receives.  If for some reason the signed string on the receiving server does not match the one in the request, the request will fail with errors.

Signed requests are completely transparent in the `QuirkyApi::Client`.  On every request, regardless if they are custom or generic, everything is signed.

## Client models

Client models help parse responses by providing a default 'template' for the response.  When a request is made to a different server and the response is successful, the `QuirkyApi::Client` fills in the model used to make the request with the values of the response.

As an example, if you make a request to find user 1:


```ruby
client = QuirkyApi::Client.new
client.users.find(1)
# => #<QuirkyApi::User:0x00000103b74338 @id=1, @name="First1 Last1", @email="anon-1@example.net", ....>
```

...Then `QuirkyApi::Client` automatically knows that it's dealing with the `User` model.  The result of the above request, then, would be an instance of `QuirkyApi::User`.

  There is a file called `lib/quirky-api/client/user.rb` which contains the user model:

```ruby
module QuirkyApi
  # User model, found on QC at /api/v2/users.
  class User < Client
    api_host :qc
    api_endpoint '/api/v2/users'

    include Virtus.model

    # !@attribute [rw] id
    #   @return [Integer] the user's id on Quirky Classic
    attribute :id, Integer

    # !@attribute [rw] name
    #   @return [String] the user's name on Quirky Classic
    attribute :name, String

    # !@attribute [rw] email
    #   @return [String] the user's email on Quirky Classic
    attribute :email, String

    # so on...
  end
end
```

The user model breaks down what request should be made, to where, and what attributes to expect in the response.

### `api_host`

`api_host` defines what host to make the request to.  Current options are `:qc`, `:qtip` and `:auth`.

The `QuirkyApi::Client` figures out what the actual host is by getting the result of `config.#{api_host}_host`.  For example, if `api_host` is `:qc`, then the value of it will be `config.qc_host`, which will in turn be `http://localhost:3000`.

When a request is made, `QuirkyApi::Client` automatically gets the host as described.  The host, combined with minor logic behind `api_endpoint` as explained below, helps to generate the final request.

### `api_endpoint`

`api_endpoint` is the base controller endpoint, on the `api_host`, upon which to make requests.  `QuirkyApi::Client` has logic to mutate the `api_endpoint` string appropriately depending on what sort of request you are making.  Therefore, the value of `api_endpoint` should always end with just the controller name and no leading slash:

```ruby
api_endpoint '/api/v2/users'
```

#### Endpoint mutation

As already stated, the client has logic to mutate the endpoint as appropriate to the specific request you're making.  `list` and `create` will make a request to the endpoint, only needing to change the request method:

```ruby
client.users.list
# GET /api/v2/users

client.users.create(name: 'Mike', email: 'test@example.com')
# POST /api/v2/users
```

`find`, `update` and `destroy` will automatically append the ID you specify to the `api_endpoint` value, and use the appropriate request method:


```ruby
client.users.find(1)
# GET /api/v2/users/1

client.users.update(1, name: 'Tom')
# PUT /api/v2/users/1

cilent.users.destroy(1)
# DELETE /api/v2/users/1
```

### Virtus model

[virtus](https://github.com/solnic/virtus) is a gem that helps define classes as "pseudo" models of sorts.  Be sure to `include Virtus.model` and specify each attribute in the format of:

```ruby
attribute :attribute_name, ClassDistinction
```

In the above example, notice that `:attribute_name` is the name of the attribute and `ClassDistinction` is a representation of the class that the attribute's value should be.  So, `:id` is an `Integer`, and `:email` is a `String`.  Any valid type class is acceptable.
