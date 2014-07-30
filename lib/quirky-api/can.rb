# encoding: utf-8
module QuirkyApi
  # Provides CanCanCan functionality.
  module Can
    def authorize!(ability, obj, *args)
      ::Ability.new(current_user).authorize!(ability, obj, args)
    end

    def can?(action, subject, *args)
      ::Ability.new(current_user).can?(action, subject, args)
    end

    def cannot?(action, subject, *args)
      ::Ability.new(current_user).cannot?(action, subject, args)
    end
  end
end
