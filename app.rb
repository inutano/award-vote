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
  
  helpers do
    def app_root
      "#{env["rack.url_scheme"]}://#{env["HTTP_HOST"]}#{env["SCRIPT_NAME"]}"
    end
  end
  
  get "/:source.css" do
    sass params[:source].intern
  end
  
  get "/" do
    haml :index
  end
  
  post "/confirm" do
    @vote = params["vote"]
    haml :confirm
  end
  
  post "/complete" do
    @vote = params["vote"]
    
    ballot = Ballot.new
    ballot.mail = ""
    ballot.db = ""
    ballot.tool = ""
    ballot.web = ""
    ballot.mes = ""
    ballot.save
    
    haml :complete
  end
  
  get "/result" do
    haml :result
  end
end
