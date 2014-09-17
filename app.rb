# :)

require "sinatra"
require "sinatra/activerecord"
require "haml"
require "sass"

require "json"
require "open-uri"
require "./ballot"

ENV["DATABASE_URL"] ||= "sqlite3:database.sqlite"

class OpenScienceAward < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  set :database, ENV["DATABASE_URL"]
  
  def csv_importer(dsw, header = true)
    csv_raw = open(app_root + "/#{dsw}.tsv", "r:utf-8").readlines
    csv_head = csv_raw.shift if header
    csv_raw.map do |line_n|
      line = line_n.chomp.split("\t")
      { name: line[0],
        dev_by: line[1],
        url: line[2],
        note: line[3],
        year: line[5],
        winner: line[6],
        category: line[7] }
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
  
  def count_of_votes(dsw)
    votes = Ballot.all.map do |r|
      r.send(dsw).split("\t").select{|n| n!= "" }
    end
    votes_count = {}
    votes.flatten.each do |vote|
      votes_count[vote] ||= 0
      votes_count[vote] += 1
    end
    votes_count.sort_by{|k,v| v }.reverse
  end
  
  def past_winners(dsw, option)
    list = count_of_votes(dsw)
    winners = csv_importer("winners", header=false)
    case option
    when :get
      winners.map do |w|
        name = w[:name]
        points = list.select{|n| n.first == name }.flatten.last || 0
        [ name, points, w[:year], w[:winner], w[:category] ]
      end
    when :remove
      list.select{|n| !winners.map{|n| n[:name] }.include?(n.first) }
    end
  end
  
  def top10(dsw)
    count, prev_votes, prev_stand  = 0, 0, 0
    past_winners(dsw, :remove).map do |row|
      count += 1
      name = row.first
      votes = row.last
      
      standing = if prev_votes == votes
                   prev_stand
                 else
                   count
                 end
      
      if count <= 10 || votes == prev_votes
        prev_votes = votes
        prev_stand = standing
        [name, votes, standing]
      end
    end
  end
  
  def pole_result
    [:db,:sw,:web].map do |sym|
      { "category" => sym.to_s,
        "data" => top10(sym).compact }
    end
  end
  
  def legends_result
    [:db,:sw,:web].map do |sym|
      { "category" => sym.to_s,
        "data" => past_winners(sym, :get) }
    end
  end
  
  helpers do
    def app_root
      "#{env["rack.url_scheme"]}://#{env["HTTP_HOST"]}#{env["SCRIPT_NAME"]}"
    end
  end
  
  get "/:source.css" do
    sass params[:source].intern
  end
  
  ## get "/" do
  get "/nominated" do
    haml :index
  end
  
  get "/nominates" do
    redirect "https://docs.google.com/spreadsheet/ccc?key=0AuGuThBjkm2EdGJMVkxlcXh2UEsxLVFfeHQ0S1YtSHc&usp=sharing"
  end
  
  post "/confirm" do
    db = params[:database] || []
    sw = params[:software] || []
    web = params[:web] || []
    @cert = valid_vote?(db + sw + web)
    
    @vote = { database: db,
              software: sw,
              web: web }
    haml :confirm
  end
  
  post "/voted" do
    @vote = { database: params[:database] || [],
              software: params[:software] || [],
              web: params[:web] || [] }
    
    ballot = Ballot.new
    ballot.db = @vote[:database].join("\t")
    ballot.sw = @vote[:software].join("\t")
    ballot.web = @vote[:web].join("\t")
    ballot.mail = params[:mail]
    ballot.mes = params[:message]
    ## ballot.save
    
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
    content_type "application/json"
    JSON.dump(pole_result)
  end
  
  get "/legends" do
    content_type "application/json"
    JSON.dump(legends_result)
  end
  
  ## get "/pole_result" do
  get "/" do
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
