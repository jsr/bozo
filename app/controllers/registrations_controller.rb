#
#
#
class RegistrationsController

  #
  #
  #
  def new
    super
  end

  #
  #
  #
  def create
    super
    session[:omniauth] = nil unless @user.new_record?
  end

  #
  #
  #
  def update
    super
  end


  #\\\\\\\\\\\\\\\\\\\\\\\\\\\
  private

  #
  #
  #
  def build_resource(*args)
    super
    if session[:omniauth]
      @user.apply_omniauth(session[:omniauth])
      @user.valid?
    end
  end
end 