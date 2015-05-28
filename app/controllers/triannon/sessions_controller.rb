require_dependency "triannon/application_controller"

module Triannon
  # This copied from https://github.com/intridea/omniauth#integrating-omniauth-into-your-application
  class SessionsController < ApplicationController
    def create
      @user = User.find_or_create_from_auth_hash(auth_hash)
      self.current_user = @user
      redirect_to '/'
    end

    protected

    def auth_hash
      request.env['omniauth.auth']
    end
  end

end # Triannon
