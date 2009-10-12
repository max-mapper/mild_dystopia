require 'rubygems'
require 'sinatra'
require 'environment'

use Rack::OpenID
use Rack::Session::Cookie
set :sessions, true

helpers do
  include Rack::Utils
  alias_method :escaped, :escape_html
  
  def partial(page, options={})
    haml page, options.merge!(:layout => false)
  end
  
end

configure do
  set :views, "#{File.dirname(__FILE__)}/views"
end

error do
  e = request.env['sinatra.error']
  Kernel.puts e.backtrace.join("\n")
  'Application error'
end

before do
  @powertron ||= PowerTron.new
  if session[:openid]
    @username ||= @powertron.get_user(session[:openid])
    if @username
      @email ||= @powertron.get_email(@username)
    end
  else
    @username = nil
  end
end

get '/' do
  session[:error] = nil
  @posts = @powertron.get_posts(20)
  haml :root
end

get '/main.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :main
end

post '/login' do
  if resp = request.env["rack.openid.response"]
    if resp.status == :success
      email = resp.message.get_arg("http://openid.net/srv/ax/1.0", "value.email")
      id = resp.display_identifier
      session[:openid] = id
      session[:email] = email
      redirect '/pickusername'
    else
      "Aieeee: #{resp} #{request.inspect}"
    end
  else
    headers 'WWW-Authenticate' => Rack::OpenID.build_header(
      :identifier => params["openid_identifier"]
    )
    throw :halt, [401, 'got openid?']
  end
end

get '/logout' do
  session[:openid] = nil
  redirect '/'
end

post '/save' do
  username_exists = @powertron.save_user(params['username'], session[:openid], session[:email])
  if username_exists
    session[:error] = "Username already taken. Try again"
    redirect '/pickusername'
  end
  session[:error] = nil
  redirect '/'
end

post '/textpost' do
  @powertron.add_post(params['textarea'], @username)
  redirect '/'
end

post '/imagepost' do
  unless params[:file] &&
         (tmpfile = params[:file][:tempfile]) &&
         (name = params[:file][:filename])
       redirect '/'
  end
  File.open("#{File.dirname(__FILE__)}/public/uploads/#{name}", 'wb') {|f| f.write(tmpfile.read) }
  @powertron.add_post(params[:caption], @username, name)
  redirect '/'
end

get '/pickusername' do
  username = @powertron.get_user(session[:openid])
  if !username
    haml :pickusername
  else
    redirect '/'
  end
end