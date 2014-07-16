# Quirky API

The Quirky API gem provides the base functionality for API usage across all Quirky apps.

All functionality will automatically be included by adding the `quirky-api` gem to your Gemfile:

```ruby
gem 'quirky-api', '0.2.0'
```

## Usage

API controllers may be namespaced however you wish, but should always inherit from `QuirkyApi::Base`.  No further action is required.

```ruby
module Api
  module V1
    class TestController < QuirkyApi::Base
    end
  end
end
```

## Rendering content

Always use `respond_with` to render your content.

```ruby
module Api
  module V1
    class TestController < Quirky::Base
      def index
        respond_with Test.paginate(page: 1 || params[:page], per_page: 15 || params[:per_page])
      end
    end
  end
end
```

`respond_with` will always return the output in json, wrapped in a "data" key:

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

There are a few caveats to how `respond_with` works:

* If your content is an array, it will *always* return an array, regardless of the number of elements in said array.  `respond_with` will attempt to serialize every object in the array.
* If you pass a single object, it will return that single object, serialized:

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
* If you pass a boolean value, or nil, it will still return the data key but respond only with the boolean value:

  ```ruby
  respond_with true # or false, or nil
  ```
  ```json
  {
    "data": true
  }
  ```
* If you pass a hash, you *must* surround your hash with parenthesis.  `respond_with` will not attempt to serialize anything in a hash.  If you wish to serialize something, you must serialize it yourself:

  ```ruby
  respond_with({
    bool: true,
    user_id: 1,
    user: UserSerializer.new(User.first).as_json(root: false),
    followers: QuirkyArraySerializer.new(User.first.followers).as_json(root: false)
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
    "errors": "Couldn't find User with 'id'=9999999999"
  }
  ```

`respond_with` also accepts an optional `status` option, as a second parameter.  The `status` option will specify the status code that the response should return.

```ruby
@user = User.create!(...)
respond_with @user, status: 201 # Or any other valid status code
```

`respond_with` also accepts an optional `elements` option, as a second parameter.  `elements` will let you specify top-level keys for the JSON output:

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

## Serializers

The Quirky API gem exposes a slightly altered instance of ActiveModel Serializers.  AMS serializes data and returns only what you want to return.

Serializers should be placed in the `app/serializers` directory, and be named `model_name_serializer.rb`.  They should have this structure:

```ruby
class ModelNameSerializer < QuirkySerializer
  attributes :id, :name, :last_name, :fav_animal
  associations :profile, :avatar
  default_associations :profile
  optional :town, :age

  def fav_animal
    # This overrides the default avlue of fav_animal.
    'Giraffe'
  end

  def age
    # Use object to reference the model.
    if object.age > 20 && object.age < 40
      'Young'
    elsif object.age > 40
      'Old'
    else
      'Really young'
    end
  end
end
```

Let's go over what all of this means:

### Attributes

```ruby
attributes :id, :name, :last_name
```

This will specify what attributes will appear by default when serializing content with this serializer.  Attributes can be be any column or method that exists on the model, or even something that you want to set up manually:

* If the model has a column of the same name as the attribute, the attribute will be the value of that column on the model.
* If the model has a method, scope or association of the same name as the attribute, the attribute's value will be the result of calling that method, scope or association.
* If the model has no method, scope, association or column of the same name as the attribute, you must manually specify the value:

  ```ruby
  def fav_animal
    # Use object to reference the model.
    object.favorite_animal
  end
  ```

In all cases, the value of the attribute can be overridden by specifying a method of the same name.  The attribute's value will then be the result of that method.

Attributes are not individually serialized.  If you wish to serialize the output of one attribute, do it manually.

### Associations

```ruby
associations :profile, :avatar
```

Associations are similar to attributes, but they *are* serialized individually.  The output of associations follow the same rules as attributes.

Once we have the output of an association, QuirkyApi attemps to find a serializer that matches the object returned, and run that serializer on that object.  The serialized objecet is the final value.

Associations do not show up by default unless specified (see below).  You may ask for associations in the request:

```
GET api/v1/users?associations[]=profile&associations[]=avatar
```

Or through `respond_with`:

```ruby
respond_with User.all, associations: ['profile', 'avatar']
```

### Default Associations

```ruby
default_associations :profile
```

Default associations are associations that always appear in the output, regardless of whether you ask for them or not.  Default associations must individually match a value in the `associations` list.

You cannot request default associations.

### Optional fields

```ruby
optional :town, :age
# ...

def age
  if object.age > 20 && object.age < 50
    'Young'
  elsif object.age > 50
    'Old'
  else
    'Really young'
  end
end
```

Optional fields are similar to attributes in their execution and output, but must be requested to show up.  Optional fields are not serialized, unless you do it manually.

You may request optional fields with the `extra_fields` array in a request:

```
GET api/v1/users?extra_fields[]=town&extra_fields[]=age
```

Or as an optional parameter in `respond_with`:

```ruby
respond_with User.all, extra_fields: ['town', 'age']
```
