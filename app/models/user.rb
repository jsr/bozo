#
#
#
class User
  include MongoMapper::Document
  plugin MongoMapper::Devise

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable

  has_many :authentications, :dependent => :destroy

  # Attributes
  key :email,                 String
  key :encrypted_password,    String
  key :password_salt,         String
  key :reset_password_token,  String
  key :remember_token,        String
  key :remember_created_at,   Time
  key :sign_in_count,         Integer
  key :current_sign_in_at,    Time
  key :last_sign_in_at,       Time
  key :current_sign_in_ip,    String
  key :last_sign_in_ip,       String
  key :email_alert,           Boolean
  key :sms_alert,             Boolean
  key :weekend,               Boolean
  key :estime,                Time
  key :eetime,                Time
  key :sstime,                Time
  key :setime,                Time
  key :nick,                  String
  key :sms_address,           String
  timestamps!

  # Validations
  REG_EMAIL_NAME  = '[\w\.%\+\-]+'
  REG_DOMAIN_HEAD = '(?:[A-Z0-9\-]+\.)+'
  REG_DOMAIN_TLD  = '(?:[A-Z]{2}|com|org|net|gov|mil|biz|info)'
  REG_EMAIL_OK    = /\A#{REG_EMAIL_NAME}@#{REG_DOMAIN_HEAD}#{REG_DOMAIN_TLD}\z/i

  validates_length_of :email, :within => 6..100, :allow_blank => true
#  validates_format_of :email, :with => REG_EMAIL_OK, :allow_blank => true


  #
  #
  #
  def apply_omniauth(omniauth)
    self.email = omniauth['user_info']['email'] if email.blank?

    if nick.blank?
      self.nick = (omniauth['user_info']['first_name'] || omniauth['user_info']['nickname'] ||
                   omniauth['user_info']['name'] ||omniauth['user_info']['email'])
    end

    self.email_alert = false
    self.sms_alert = false
    self.weekend = false

    authentications.build(:provider => omniauth['provider'], :uid => omniauth['uid'])
  end

  #
  #
  #
  def password_required?
    (authentications.empty? || !password.blank?) && super
  end


end # of class
