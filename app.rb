# dev hint: shotgun login.rb

require 'rubygems'
require 'sinatra'
require 'databasedotcom'
require 'omniauth'
require 'omniauth-google-oauth2'



configure do
  set :public_folder, Proc.new { File.join(root, "static") }
  enable :sessions
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello stranger'
  end  
end

before '/secure/*' do
  if !session[:authenticated] then
    session[:previous_url] = request['REQUEST_PATH']
    @error = "Sorry guacamole, you need to be logged in to do that."
    halt erb "<a href='/auth/google_oauth2'>Login here.</a>"
  end
end

get '/' do
  erb 'Can you handle a <a href="/secure/place">secret</a>?'
end

post '/login/attempt' do
  session[:identity] = params['username']
  where_user_came_from = session[:previous_url] || '/'
  redirect to where_user_came_from 
end

get '/logout' do
  session.delete(:identity)
  session.delete(:email)
  session[:authenticated] = false
  erb "<div class='alert alert-message'>Logged out</div>"
end


get '/secure/place' do
  identity = initalize_salesforce
  output = "<h4>This is a secret place that only <%=session[:identity]%> has access to!</h4>"
  output << "<dl class='dl-horizontal'>"
  identity.attributes.each { |k,v| output << "<dt>#{k.to_s}</dt><dd>#{v.to_s}&nbsp;</dd>" }
  output << "</dl>"
  erb output
end

get '/auth/:provider/callback' do
  session[:identity] =  request.env['omniauth.auth']["info"]["name"]
  session[:email] =  request.env['omniauth.auth']["info"]["email"]
  session[:authenticated] = true
  redirect "/secure/place"
end

get '/auth/failure' do
  content_type 'text/plain'
  request.env['omniauth.auth'].to_hash.inspect rescue "No Data"
end

def initalize_salesforce
    client = Databasedotcom::Client.new(:client_id => ENV["SF_KEY"], :client_secret => ENV["SF_SECRET"] )
    client.authenticate(:username => ENV["SF_USER"], :password => ENV["SF_USER_PASS"] )
    # Dynamic loading of the User object metadata
    # this will create a Class called User in the current NameSpace / Module
    client.materialize("Contact")
    return Contact.find_by_Name(session[:identity])
end


use Rack::Session::Cookie, :secret => ENV['RACK_COOKIE_SECRET']

use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET']
end


