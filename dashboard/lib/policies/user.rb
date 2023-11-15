class Policies::User
  # Returns the user.attributes along with the attributes of select
  # associations.
  def self.user_attributes(user)
    attributes = user.attributes
    authentication_options = user.authentication_options.map {|ao| ao.attributes.compact}
    attributes.merge('authentication_options_attributes' => authentication_options).compact
  end

  def self.assign_form_params(user, params)
    assign_auth_option_params(user, params)
    user.assign_attributes(params.compact)
  end

  def self.assign_auth_option_params(user, params)
    #"authentication_options_attributes"=>{"0"=>{"email"=>"test@example.com"}}
    params_aos = params['authentication_options_attributes']
    if params_aos
      user.authentication_options&.each_with_index do |user_ao, index|
        # Get the authentication option settings from the form params
        params_ao = params_aos[index.to_s]
        # Apply the form params to the AuthenticationOption
        user_ao.assign_attributes(params_ao.compact)
      end
    end
    params.delete('authentication_options_attributes')
  end
end
