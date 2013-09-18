# :)

require "sinatra"
require "sinatra/activerecord"
require "haml"
require "sass"

require "open-uri"
require "./ballot"

ENV["DATABASE_URL"] ||= "sqlite3:///database.sqlite"

class OpenScienceAward < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  set :database, ENV["DATABASE_URL"]
  
  set :haml, :format => :html5
  set :haml, :escape_html => true
  
  def csv_importer(dsw)
    csv_raw = open(app_root + "/#{dsw}.csv", "r:utf-8").readlines
    csv_head = csv_raw.shift
    csv_raw.map do |line_n|
      line = line_n.split(",")
      { name: line[0],
        dev_by: line[1],
        url: line[2].gsub("http://",""),
        note: line[3] }
    end
  end
  
  def nominates
    { database: csv_importer("database"),
      software: csv_importer("software"),
      web: csv_importer("web") }
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
    haml :index
  end
  
  post "/confirm" do
    @database = params[:database]
    @software = params[:software]
    @web = params[:web]
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
