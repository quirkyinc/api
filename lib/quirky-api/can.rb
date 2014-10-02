# encoding: utf-8
module QuirkyApi
  # Provides CanCanCan functionality.
  module Can
    def authorize!(ability, obj, *args)
      current_ability.authorize!(ability, obj, args)
    end

    def can?(action, subject, *args)
      current_ability.can?(action, subject, args)
    end

    def cannot?(action, subject, *args)
      current_ability.cannot?(action, subject, args)
    end

    def current_ability
      @current_ability ||= ::Ability.new(current_user)
    end
  end
end
