require_dependency "triannon/application_controller"

module Triannon
  class SessionsController < ApplicationController
    # def new
    #   @identity = request.env['omniauth.auth']
    # end

    def create
      # Note: this code aims to provide a way for a known application, like
      # SearchWorks, to authenticate to triannon and provide information about
      # members of authorized workgroups so that triannon can respond with an
      # array of authorized annotation containers.  The secure information is
      # stored in session data, while the insecure information is available in
      # cookies.  TODO: determine whether to use secure cookies.
      @identity = request.env['omniauth.auth']
      # TODO: switch yard for different providers?
      raise 'Cannot work with provider' unless @identity['provider'] == 'developer'
      if authenticate(@identity['info'])
        current_user = @identity.to_json
        # TODO: find LDAP data and add container info to cookie?
        # workgroups = request.headers['TBD']
        workgroups = ['sul-curators',]
        find_containers(workgroups) # set containers in cookies
        respond_to do |format|
          # TODO: support a json response format
          # format.json {
          #   accept_return_type = mime_type_from_accept(["application/json", "text/x-json", "application/jsonrequest"])
          #   render :json => @identity.to_json, content_type: accept_return_type
          # }
          format.html {
            redirect_to root_url, notice: 'Successfully authenticated.'
            # render :create
          }
        end
      else
        failure
      end
      # NOTE: code commented out here relies in using a conventional rails db
      # persistence layer that is not available in triannon.
      # user = User.find_or_create_from_auth_hash(auth_hash)
      # self.current_user = user
      # redirect_to root_url, :notice => "Logged in successfully."
    end

    def destroy
      current_user = nil
      cookies[:containers] = nil
      redirect_to root_url, notice: 'Successfully logged out.'
    end

    def failure
      redirect_to root_url, alert: "Failed to authorize: #{@identity['uid']}"
    end

    private

    # Authenticates a known application client
    # @param app [Hash] app['name'] and app['email'] identify an application
    def authenticate(app)
      # TODO: use a configuration value to authenticate known apps; triannon
      # has no user db (as yet)
      # @authorized_apps ||= JSON.parse(ENV['AUTHORIZED_APPS'])
      @authorized_apps ||= {'SearchWorks' => 'secret', 'Mirador' => 'secret'}
      @authorized_apps[app['name']] == app['email']
    end

    # Sets cookies[:containers] to authorized annotation containers.
    # @param workgroups [Array<String>] An array of LDAP workgroups
    def find_containers(workgroups)
      # TODO: use a configuration value to map workgroups to containers
      # @containers ||= JSON.parse(ENV['WORKGROUP_CONTAINERS'])
      @containers ||= {'sul-curators' => ['annotations']}
      containers = workgroups.collect {|g| @containers[g] }.compact
      cookies[:containers] = containers.flatten.uniq
    end

  end
end
