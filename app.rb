# :)

require "sinatra"
require "sinatra/activerecord"
require "haml"
require "sass"

require "./ballot"

ENV["DATABASE_URL"] ||= "sqlite3:///database.sqlite"

class OpenScienceAward < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  set :database, ENV["DATABASE_URL"]
  
  set :haml, :format => :html5
  set :haml, :escape_html => true
  
  configure do
    enable :sessions
  end
  
  helpers do
    def app_root
      "#{env["rack.url_scheme"]}://#{env["HTTP_HOST"]}#{env["SCRIPT_NAME"]}"
    end
  end
  
  get "/:source.css" do
    sass params[:source].intern
  end
  
  get "/" do
    session.clear
    haml :index
  end
  
  post "/confirm" do
    @vote = params["vote"]
    session[:vote] = @vote
    haml :confirm
  end
  
  post "/complete" do
    @vote = session[:vote]
    haml :complete
    session.clear
  end
  
  get "/result" do
    haml :result
  end
  
  get "/data" do
  end
end
