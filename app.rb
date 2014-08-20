# :)

require "sinatra"
require "sinatra/activerecord"
require "haml"
require "sass"

require "json"
require "open-uri"
require "./ballot"

ENV["DATABASE_URL"] ||= "sqlite3:///database.sqlite"

class OpenScienceAward < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  set :database, ENV["DATABASE_URL"]
  
  set :haml, :format => :html5
  set :haml, :escape_html => true
  
  def csv_importer(dsw)
    csv_raw = open(app_root + "/#{dsw}.tsv", "r:utf-8").readlines
    csv_head = csv_raw.shift
    csv_raw.map do |line_n|
      line = line_n.split("\t")
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
  
  def get_url_hash
    hash = {}
    db = csv_importer("database")
    sw = csv_importer("software")
    web = csv_importer("web")
    (db + sw + web).each do |item|
      hash[item[:name]] = item[:url]
    end
    hash
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
  
  post "/voted" do
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
    
    haml :voted
  end
  
  get "/count" do
    categ = params[:category]
    all = Ballot.all

    db_votes = all.map{|r| r.send(categ.intern).split("\t") }.flatten
    votes_count = {}
    db_votes.each do |vote|
      votes_count[vote] ||= 0
      votes_count[vote] += 1
    end
    
    content_type "application/json"
    JSON.dump(votes_count.sort_by{|k,v| v }.reverse)
  end
  
  get "/getresult" do
    all = Ballot.all
    pole_result = [:db, :sw, :web].map do |sym|
      votes = all.map do |r|
        r.send(sym).split("\t").select{|n| n != "" }
      end
      votes_count = {}
      votes.flatten.each do |vote|
        votes_count[vote] ||= 0
        votes_count[vote] += 1
      end
      { category: sym.to_s, data: votes_count.sort_by{|k,v| v }.reverse }
    end
    content_type "application/json"
    JSON.dump(pole_result)
  end
  
  get "/pole_result" do
    all = Ballot.all
    @num_of_votes = all.length
    haml :result
  end
  
  get "/result" do
    all = Ballot.all
    @num_of_votes = all.length
    @db = JSON.load(open(app_root + "/count?category=db"))
    @sw = JSON.load(open(app_root + "/count?category=sw"))
    @web = JSON.load(open(app_root + "/count?category=web"))
    content_type "application/json"
    JSON.dump({ votes: @num_of_votes, db: @db, sw: @sw, web: @web })
  end
end
