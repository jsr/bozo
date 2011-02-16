#
#
#
class AuthenticationsController < ApplicationController

  #
  #
  #
  def index
    @authentications = current_user.authentications if current_user
  end


  #
  #
  #
  def create
    omniauth = request.env["omniauth.auth"]
    authentication = Authentication.find_by_provider_and_uid(omniauth['provider'], omniauth['uid'])

    # todo: remove this, temp hack
    if authentication.blank? and current_user.nil?
      email = omniauth['user_info']['email']
      u = User.find_by_email(email)
      if u
        current_user = u
      end
    end

    if authentication  # selected 'authentication' exists in the system, so sign-in the user
      flash[:notice] = "Signed in successfully."
      sign_in_and_redirect(:user, authentication.user)

    elsif current_user  # selected 'authentication' does not exists in the system, so create a new one for the signed-in user
      current_user.authentications.create(:provider => omniauth['provider'], :uid => omniauth['uid'])

      flash[:notice] = "Authentication successful."
      redirect_to root_url

    else   # user does not exists in the system, so create a new user + new authentication
      user = User.new
      user.apply_omniauth(omniauth)

      if user.save
        flash[:notice] = "Signed in successfully."
        sign_in_and_redirect(:user, user)
      else
        if not user.errors[:email].blank?
          user.errors[:email].clear
          user.errors[:email] = "'#{omniauth['user_info']['email']}' is already in use. Please use appropriate
                                  service (the one you used first time) to login."
        end

        flash[:error] = user.errors.full_messages.join(", ")
        session[:omniauth] = omniauth.except('extra')

        redirect_to new_user_session_url
      end
    end
  end


  #
  #
  #
  def destroy
    @authentication = current_user.authentications.find(params[:id])
    @authentication.destroy
    flash[:notice] = "Successfully destroyed authentication."

    redirect_to authentications_url
  end

end # of controller