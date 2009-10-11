require 'rubygems'
require 'rack-openid'
require 'haml'
require 'sass'
require 'redis'
require 'db'
require 'ostruct'
require 'digest/md5'
require 'sinatra' unless defined?(Sinatra)

configure do
  SiteConfig = OpenStruct.new(
                 :title => 'Mild Dystopia',
                 :author => 'Max Ogden',
                 :url => 'http://www.milddystopia.com/',
                 :url_base => 'www.milddystopia.com'
               )
end

def google_openid_action
"https://www.google.com/accounts/o8/ud?openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.return_to=http%3A%2F%2F#{SiteConfig.url_base}%2Flogin%3F_method%3Dpost&openid.realm=http%3A%2F%2F#{SiteConfig.url_base}%2F&openid.assoc_handle=ABSmpf6DNMw&openid.mode=checkid_setup&openid.ns.ext1=http%3A%2F%2Fopenid.net%2Fsrv%2Fax%2F1.0&openid.ext1.mode=fetch_request&openid.ext1.type.email=http%3A%2F%2Faxschema.org%2Fcontact%2Femail&openid.ext1.required=email"
end


# Returns a Gravatar URL associated with the email parameter.
def gravatar_url(email,gravatar_options={})

  # Default highest rating.
  # Rating can be one of G, PG, R X.
  # If set to nil, the Gravatar default of X will be used.
  gravatar_options[:rating] ||= nil

  # Default size of the image.
  # If set to nil, the Gravatar default size of 80px will be used.
  gravatar_options[:size] ||= "60px" 

  # Default image url to be used when no gravatar is found
  # or when an image exceeds the rating parameter.
  gravatar_options[:default] ||= "http://#{SiteConfig.url_base}/defaultavatar.png"

  # Build the Gravatar url.
  grav_url = 'http://www.gravatar.com/avatar.php?'
  grav_url << "gravatar_id=#{Digest::MD5.new.update(email)}" 
  grav_url << "&rating=#{gravatar_options[:rating]}" if gravatar_options[:rating]
  grav_url << "&size=#{gravatar_options[:size]}" if gravatar_options[:size]
  grav_url << "&default=#{gravatar_options[:default]}" if gravatar_options[:default]
  return grav_url
end
