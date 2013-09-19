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
        url: line[2],
        note: line[3] }
    end
  end
  
  def nominates
    { database: csv_importer("database"),
      software: csv_importer("software"),
      web: csv_importer("web") }
  end
  
  def valid_vote?(array)
    names = array.select{|n| n != "" }
    names.size == names.uniq.size
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
    db = params[:database]
    sw = params[:software]
    web = params[:web]
    @cert = valid_vote?(db + sw + web)
    
    @vote = { database: db,
              software: sw,
              web: web }
    haml :confirm
  end
  
  post "/vote" do
    @vote = { database: params[:database],
              software: params[:software],
              web: params[:web] }
    
    ballot = Ballot.new
    ballot.db = @vote[:database].join("\t")
    ballot.sw = @vote[:software].join("\t")
    ballot.web = @vote[:web].join("\t")
    ballot.mail = params[:mail]
    ballot.mes = params[:message]
    ballot.save
    
    haml :vote
  end
  
  get "/result" do
    all = Ballot.all
    db = all.map{|r| r.db.gsub("\t","\n") }.join("\n")
    sw = all.map{|r| r.sw.gsub("\t","\n") }.join("\n")
    web = all.map{|r| r.web.gsub("\t","\n") }.join("\n")
    db + sw + web
  end
end
