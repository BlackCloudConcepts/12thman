class HomeController < ApplicationController
  include Mongo
  
  # data calls ... mongo / yahoo api
  def yapi(url)
        require 'json'
        require 'open-uri'
	# https://github.com/mongodb/mongo-ruby-driver/wiki/Tutorial
	require 'mongo'

	# pulls cached data from mongo instead of calling yahoo apis if the data exists
	cacheddata = true
	@url = url

	# define mongo       
	mongoclient = MongoClient.new('localhost', 27017)
	db = mongoclient.db("12thman")
	# change collection to access older or newer cache
	coll = db.collection('apicache20131008')
	# coll = db.collection('apicache2013102')

	if (cacheddata)
		returndoc = coll.find({"userid" => @userid, "url" => @url}).to_a
		if (returndoc.length != 0)
			@data = returndoc[0]['data']
		else
#			@access_token = session[:request_token].get_access_token(:oauth_verifier=>session[:code])
			url = "http://fantasysports.yahooapis.com/"+@url
			puts "API -> "+url
			result=@access_token.get(url)
			@data = Hash.from_xml(result.body).to_json
			if (@userid != '')
				doc = {"userid" => "#{@userid}", "url" => "#{@url}", "data" => "#{@data}"}
				coll.insert(doc)	
			end
		end
	else
#		@access_token = session[:request_token].get_access_token(:oauth_verifier=>session[:code])
		url = "http://fantasysports.yahooapis.com/"+@url
		puts "API -> "+url
		result=@access_token.get(url)
		@data = Hash.from_xml(result.body).to_json
		returndoc = coll.find({"userid" => @userid, "url" => @url}).to_a
                if (returndoc.length == 0)
			if (@userid != '')
				doc = {"userid" => "#{@userid}", "url" => "#{@url}", "data" => "#{@data}"}
				coll.insert(doc)
			end
		end
	end

	return @data
  end

  # main page
  def view
	require 'json'
	require 'rest_client'

	# http://oauth.rubyforge.org
	# http://developer.yahoo.com/fantasysports/guide/
	# http://developer.apps.yahoo.com/projects/RM9aza50
	# http://developer.yahoo.com/fantasysports/guide/game-resource.html
	# http://json.parser.online.fr

	begin	
		@access_token = session[:request_token].get_access_token(:oauth_verifier=>params[:code])
	rescue Exception => e
		redirect_to "http://12thman.blackcloudconcepts.com" and return
		# try to exchange an access token for a new access token on expiration instead of redirect
=begin
		request_token = OAuth::RequestToken.new(@consumer, 
                	@access_token,             
                      	"992785c3d4bd3170262f8d544702f9fbcd48d5ea")
		token = OAuth::Token.new(@access_token,
                     	"992785c3d4bd3170262f8d544702f9fbcd48d5ea")
		@access_token = request_token.get_access_token(
                      	:oauth_session_handle => @access_token.params['oauth_session_handle'],
                     	:token => token)
=end
	end
	session[:code]=params[:code]

	@weights = JSON.parse(params[:weights])

	@arrPosition = Array.new
	@arrPosition << {'position' => 'QB'}
	@arrPosition << {'position' => 'RB'}
	@arrPosition << {'position' => 'WR'}
	@arrPosition << {'position' => 'TE'}
	@arrPosition << {'position' => 'DEF'}
	@arrPosition << {'position' => 'K'}

# 	API EXAMPLE	
#	url = "http://railroadtracks.blackcloudconcepts.com/yapi/"+CGI::escape('fantasy/v2/game/nfl'.gsub("/", "|"))
#	@data = RestClient.get url

#	METHOD EXAMPLE
#	url = 'fantasy/v2/game/nfl'
#	@output = yapi(url)

	# setting the userid to ''.  The first 2 api calls will be made on each page load even when using cached data as they don't have the userid yet
	@userid = ""	

	# game
	@data = yapi("fantasy/v2/game/nfl")
	@data = JSON.parse(@data)
	@gameid = @data['fantasy_content']['game']['game_id']
	@gamekey = @data['fantasy_content']['game']['game_key']

	# user
	@data = yapi("fantasy/v2/users;use_login=1/games;game_keys="+@gameid+"/leagues")
	@data = JSON.parse(@data)
	
	# check for no league 
	if (@data['fantasy_content']['users']['user']['games']['game']['leagues'] == nil)
		@leaguename = "NO ACTIVE LEAGUES"
		@roster = Array.new
		@availableplayers = Array.new
		return false;
	end
	@userid = @data['fantasy_content']['users']['user']['guid']
	if (@data['fantasy_content']['users']['user']['games']['game']['leagues']['league'].kind_of?(Array))
		len = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league'].length-1
		@leagueid = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league'][len]['league_id']
                @leaguekey = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league'][len]['league_key']
                @leaguename = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league'][len]['name']
	else 
		@leagueid = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league']['league_id']
		@leaguekey = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league']['league_key']
		@leaguename = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league']['name']
	end
	
	# teams
	@data = yapi("fantasy/v2/users;use_login=1/games;game_keys="+@gameid+"/teams")
	@data = JSON.parse(@data)
	if (@data['fantasy_content']['users']['user']['games']['game']['teams']['team'].kind_of?(Array))
		len = @data['fantasy_content']['users']['user']['games']['game']['teams']['team'].length-1
		@teamid = @data['fantasy_content']['users']['user']['games']['game']['teams']['team'][len]['team_key']
		@teamname = @data['fantasy_content']['users']['user']['games']['game']['teams']['team'][len]['name']
		@teamlogo = @data['fantasy_content']['users']['user']['games']['game']['teams']['team'][len]['team_logos']['team_logo']['url']
	else
		@teamid = @data['fantasy_content']['users']['user']['games']['game']['teams']['team']['team_key']
		@teamname = @data['fantasy_content']['users']['user']['games']['game']['teams']['team']['name']
		@teamlogo = @data['fantasy_content']['users']['user']['games']['game']['teams']['team']['team_logos']['team_logo']['url']
	end

	# defensive rank
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;position=DEF;count=25;start=0;sort=PTS/stats")
        @data = JSON.parse(@data)
	@arr = @data['fantasy_content']['league']['players']['player']
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;position=DEF;count=25;start=25;sort=PTS/stats")
        @data = JSON.parse(@data)
        @arr2 = @data['fantasy_content']['league']['players']['player']
	@arr = @arr.zip(@arr2).flatten.compact
	@defensiverank = Array.new
	# rank can be better defined thru more data in the future ... for now its based on total fantasy points so far this season
	rank = 1
	@arr.length.times do |i|
		stat_pointsallowed = '0'
		@arr[i]['player_stats']['stats']['stat'].length.times do |j|
			if (@arr[i]['player_stats']['stats']['stat'][j]['stat_id'] == '31')
				stat_pointsallowed = @arr[i]['player_stats']['stats']['stat'][j]['value']
			end
		end
		@defensiverank << {
			'key' => @arr[i]['player_key'],
			'name' => @arr[i]['editorial_team_full_name'],
			'teamabbr' => @arr[i]['editorial_team_abbr'],
			'stat_pointsallowed' => stat_pointsallowed,
			'points' => @arr[i]['player_points']['total'],
			'rank' => rank
		}
		rank = rank + 1
	end

	# roster
	@data = yapi("fantasy/v2/team/"+@teamid+"/roster/players/stats;type=season")
	@data = JSON.parse(@data)
	@week = @data['fantasy_content']['team']['roster']['players']['player'][0]['selected_position']['week'].to_i
	@arr = @data['fantasy_content']['team']['roster']['players']['player']
	@roster = Array.new
	@arr.length.times do |i|
		hsh = Hash.new
		hsh['key'] = @arr[i]['player_key']
		hsh['name'] = @arr[i]['name']['full']
		hsh['position'] = @arr[i]['display_position']
		hsh['picture'] = @arr[i]['headshot']['url']
		hsh['teamabbr'] = @arr[i]['editorial_team_abbr']
		hsh['playerid'] = @arr[i]['editorial_player_key']
		hsh['seasonpoints'] = @arr[i]['player_points']['total']
		hsh['defrank'] = defrankcalculation(@arr[i]['editorial_team_abbr'], @week)
		hsh['byeweek'] = @arr[i]['bye_weeks']['week']
		@result = playerstatcalculation(@arr[i]['display_position'], @arr[i]['player_stats']['stats']['stat'])
		hsh['tds'] = @result['tds']
		hsh['turnovers'] = @result['turnovers']
		@roster << hsh
	end
	
	# roster pull last 3 weeks
	w = 3
	while w > 0 do
		@data = yapi("fantasy/v2/team/"+@teamid+"/roster/players/stats;type=week;week="+"#{@week-w}")
		@data = JSON.parse(@data)
		@arr = @data['fantasy_content']['team']['roster']['players']['player']
		@arr.length.times do |i|
			@roster.length.times do |j|
				if (@arr[i]['player_key'] == @roster[j]['key'])
					@roster[j][w.to_s+'ago'] = @arr[i]['player_points']['total']
					@result = playerstatcalculation(@roster[j]['position'], @arr[i]['player_stats']['stats']['stat'])
					@roster[j][w.to_s+'ago_tds'] = @result['tds']
					@roster[j][w.to_s+'ago_turnovers'] = @result['turnovers']
				end
			end                
		end
		w = w -1
	end 
	@roster = calculate12thmannumber(@roster)
	
	# stat categories
	@data = yapi("fantasy/v2/game/"+@gamekey+"/stat_categories")
	@data = JSON.parse(@data)
	@arr = @data['fantasy_content']['game']['stat_categories']['stats']['stat']
	@statids = Array.new
	@arr.length.times do |i|
		@statids << {
			'id' => @arr[i]['stat_id'],
			'name' => @arr[i]['name']
		}
	end

	# available players
	@arr = Array.new
	@availableplayers = Array.new
	@availableplayers << {'position' => 'QB', 'stats' => Array.new}
	@availableplayers << {'position' => 'RB', 'stats' => Array.new}
	@availableplayers << {'position' => 'WR', 'stats' => Array.new}
	@availableplayers << {'position' => 'TE', 'stats' => Array.new}
	@availableplayers << {'position' => 'DEF', 'stats' => Array.new}
	@availableplayers << {'position' => 'K', 'stats' => Array.new}

	# QB
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;status=A;position=QB;sort=PTS;count=25/stats")
	@data = JSON.parse(@data)
	@arr << {'position' => 'QB', 'stats' => @data['fantasy_content']['league']['players']['player']}
	# RB
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;status=A;position=RB;sort=PTS;count=25/stats")
	@data = JSON.parse(@data)
	@arr << {'position' => 'RB', 'stats' => @data['fantasy_content']['league']['players']['player']}
	# WR
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;status=A;position=WR;sort=PTS;count=25/stats")
	@data = JSON.parse(@data)
	@arr << {'position' => 'WR', 'stats' => @data['fantasy_content']['league']['players']['player']}
	# TE
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;status=A;position=TE;sort=PTS;count=25/stats")
	@data = JSON.parse(@data)
	@arr << {'position' => 'TE', 'stats' => @data['fantasy_content']['league']['players']['player']}
	# DEF
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;status=A;position=DEF;sort=PTS;count=25/stats")
	@data = JSON.parse(@data)
	@arr << {'position' => 'DEF', 'stats' => @data['fantasy_content']['league']['players']['player']}
	# K
	@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;status=A;position=K;sort=PTS;count=25/stats")
        @data = JSON.parse(@data)
        @arr << {'position' => 'K', 'stats' => @data['fantasy_content']['league']['players']['player']}
	@arr.length.times do |i| # loop 6 times from new data
		@availableplayers.length.times do |j| # loop 6 times from existing data setup
			if (@availableplayers[j]['position'] == @arr[i]['position'])
				# available players pull last 3 weeks
				@agodata = Hash.new
				@agodata['_1agodata'] = Array.new
				@agodata['_2agodata'] = Array.new
				@agodata['_3agodata'] = Array.new
				w = 3
			        while w > 0 do
					@data = yapi("fantasy/v2/league/"+@leaguekey+"/players;status=A;position="+@arr[i]['position']+";sort=PTS;count=25/stats;type=week;week="+"#{@week-w}")
					@data = JSON.parse(@data)
			                @arrweek = @data['fantasy_content']['league']['players']['player']
					@arrweek.length.times do |wk|
						@wkdata = Hash.new
						@wkdata['playerkey'] = @arrweek[wk]['player_key']
						@wkdata['playerpoints'] = @arrweek[wk]['player_points']['total']
						@wkdata['tds'] = 0
						@wkdata['turnovers'] = 0
						@result = playerstatcalculation(@arr[i]['position'], @arrweek[wk]['player_stats']['stats']['stat'])
						@wkdata['tds'] = @result['tds']
						@wkdata['turnovers'] = @result['tds']
						@agodata['_'+w.to_s+'agodata'] << @wkdata
					end
					w = w - 1
				end
				@arr[i]['stats'].length.times do |k|
					@stat = Hash.new
					@stat['key'] =  @arr[i]['stats'][k]['player_key']
					@stat['name'] = @arr[i]['stats'][k]['name']['full']
					@stat['position'] = @arr[i]['position']
					@stat['picture'] = @arr[i]['stats'][k]['headshot']['url']
					@stat['playerid'] = @arr[i]['stats'][k]['editorial_player_key']
					@stat['teamabbr'] = @arr[i]['stats'][k]['editorial_team_abbr']
					@stat['seasonpoints'] = @arr[i]['stats'][k]['player_points']['total']
					@stat['byeweek'] = @arr[i]['stats'][k]['bye_weeks']['week']
					@result = playerstatcalculation(@arr[i]['position'], @arr[i]['stats'][k]['player_stats']['stats']['stat'])
					@stat['tds'] = @result['tds']
					@stat['turnovers'] = @result['turnovers']
					@stat['defrank'] = defrankcalculation(@arr[i]['stats'][k]['editorial_team_abbr'], @week)
					@availableplayers[j]['stats'] << @stat
					# add on ago numbers
					w = 3
					while w > 0 do
						@agodata['_'+w.to_s+'agodata'].length.times do |wk|
							if (@agodata['_'+w.to_s+'agodata'][wk]['playerkey'] == @availableplayers[j]['stats'][k]['key'])
								@availableplayers[j]['stats'][k][w.to_s+'ago'] = @agodata['_'+w.to_s+'agodata'][wk]['playerpoints']
								@availableplayers[j]['stats'][k][w.to_s+'ago_tds'] = @agodata['_'+w.to_s+'agodata'][wk]['tds']
								@availableplayers[j]['stats'][k][w.to_s+'ago_turnovers'] = @agodata['_'+w.to_s+'agodata'][wk]['turnovers']
							end
						end
						w = w - 1
					end
				end
			end
		end
	end
	@availableplayers.length.times do |j|
		@availableplayers[j]['stats'] = calculate12thmannumber(@availableplayers[j]['stats'])
	end
	@availableplayers.length.times do |ap|
		@availableplayers[ap]['stats'] = @availableplayers[ap]['stats'].sort_by { |k| k['12thmannumber']}.reverse!
	end
  end

  # takes a position and stat array can outputs hash of related data
  def playerstatcalculation(position, arrStat)
	@stattotals = Hash.new
	if (position == 'QB')
		# 5 = Passing TDs
		# 6 = Interceptions
		# 10 = Rushing TDs
		# 18 = Fumbles Lost
		@tds = 0
		@turnovers = 0
		arrStat.length.times do |st|
			if (arrStat[st]['stat_id'] == '5')
				@tds = @tds + arrStat[st]['value'].to_i
			end
			if (arrStat[st]['stat_id'] == '6')
				@turnovers = @turnovers + arrStat[st]['value'].to_i
			end
			if (arrStat[st]['stat_id'] == '10')
				@tds = @tds + arrStat[st]['value'].to_i
			end
			if (arrStat[st]['stat_id'] == '18')
				@turnovers = @turnovers + arrStat[st]['value'].to_i
			end
		end
		@stattotals['tds'] =  @tds.to_s
		@stattotals['turnovers'] = @turnovers.to_s
	elsif (position == 'RB')
		# 8 = Rushing Attempts (Not used yet)
		# 9 = Rushing Yards (Not used yet)
		# 10 = Rushing TDs
		# 13 = Reception TDs
		# 18 = Fumbles Lost
		@tds = 0
                @turnovers = 0
                arrStat.length.times do |st|
                        if (arrStat[st]['stat_id'] == '10')
                                @tds = @tds + arrStat[st]['value'].to_i
                        end
                        if (arrStat[st]['stat_id'] == '13')
                                @tds = @tds + arrStat[st]['value'].to_i
                        end
                        if (arrStat[st]['stat_id'] == '18')
                                @turnovers = @turnovers + arrStat[st]['value'].to_i
                        end
                end
                @stattotals['tds'] =  @tds.to_s
                @stattotals['turnovers'] = @turnovers.to_s
	elsif (position == 'WR')
		# 11 = Receptions (Not used yet)
		# 12 = Reception Yards (Not used yet)
		# 13 = Reception TDs
		# 18 = Fumbles Lost
		@tds = 0
                @turnovers = 0
                arrStat.length.times do |st|
                        if (arrStat[st]['stat_id'] == '13')
                                @tds = @tds + arrStat[st]['value'].to_i
                        end
                        if (arrStat[st]['stat_id'] == '18')
                                @turnovers = @turnovers + arrStat[st]['value'].to_i
                        end
                end
                @stattotals['tds'] =  @tds.to_s
                @stattotals['turnovers'] = @turnovers.to_s
	elsif (position == 'TE')
		# 11 = Receptions (Not used yet)
                # 12 = Reception Yards (Not used yet)
                # 13 = Reception TDs
                # 18 = Fumbles Lost
		@tds = 0
                @turnovers = 0
                arrStat.length.times do |st|
                        if (arrStat[st]['stat_id'] == '13')
                                @tds = @tds + arrStat[st]['value'].to_i
                        end
                        if (arrStat[st]['stat_id'] == '18')
                                @turnovers = @turnovers + arrStat[st]['value'].to_i
                        end
                end
                @stattotals['tds'] =  @tds.to_s
                @stattotals['turnovers'] = @turnovers.to_s
	elsif (position == 'DEF')
		# 31 = Points Allowed
		# 32 = Sacks
		# 33 = Interception
		# 34 = Fumble Recovery
		# 35 = TDs
		# 36 = Safety
		# 50 = 56 = Points Allowed Ranges
		# 77 = 3 and outs forced
		@tds = 0
                @turnovers = 0
                arrStat.length.times do |st|
                        if (arrStat[st]['stat_id'] == '33')
                                @turnovers = @turnovers + arrStat[st]['value'].to_i
                        end
                        if (arrStat[st]['stat_id'] == '34')
                                @turnovers = @turnovers + arrStat[st]['value'].to_i
                        end

                        if (arrStat[st]['stat_id'] == '35')
                                @tds = @tds + arrStat[st]['value'].to_i
                        end
                end
                @stattotals['tds'] =  @tds.to_s
                @stattotals['turnovers'] = @turnovers.to_s
	elsif (position == 'K')
		@stattotals['tds'] =  'NA'
                @stattotals['turnovers'] = 'NA'	
	end
	return @stattotals
  end 

  # takes an array of player data and calculates the 12th Man Ratio
  def calculate12thmannumber(players)
  	players.length.times do |i|
		# EQUALIZATION
		# for each stat the goal is to make them each be equal for an average player
		# i.e avg defensive should count the same as avg recent points if set at equal weighting
		# these are equalization multipliers
		eq_seasonpoints = 1 # avg 15 / 10 * 1 = 1.5
		eq_recentpoints = 1 # avg 15 / 10 * 1 = 1.5
		eq_recenttds = 15 # avg 1 / 10 * 15 = 1.5
		eq_defrank = 1 # avg 15 / 10 * 1 = 1.5

		# if players bye week was within the last 3 weeks then divide recent numbers by 2, not 3
		avgdivider = 3
		if (((@week - players[i]['byeweek'].to_i) < 4) && (@week > players[i]['byeweek'].to_i))
			avgdivider = 2
		end
		weekdivider = @week.to_f 		# divide only by the number of weeks their team played ... ie bye week (doesn't account for injury / missed playing time)
		if (@week > players[i]['byeweek'].to_i)
			weekdivider = @week-1.to_f
		end

		# ALL POSITIONS ---------------------
		# seasonpoints (avg = 15 ... 1.5)
		seasonpoints = players[i]['seasonpoints'].to_f
		seasonpoints = (seasonpoints/weekdivider) # weekly average
		seasonpoints = eq_seasonpoints*seasonpoints*(@weights['seasonpoints'].to_f/10) # apply weight
		
		# recentpoints (avg = 15 ... 1.5)
		_3ago = players[i]['3ago'].to_f
		_2ago = players[i]['2ago'].to_f
		_1ago = players[i]['1ago'].to_f
		recentpoints = (_3ago+_2ago+_1ago)/avgdivider # weekly average
		recentpoints = eq_recentpoints*recentpoints*(@weights['recentpoints'].to_f/10) # apply weight

		# SPECIFIC POSITIONS -----------------
		# recent touchdowns (avg 1 ... .1)
		recenttds = 0
		if (['QB', 'RB', 'WR', 'TE'].include? players[i]['position'])
			_3ago = players[i]['3ago_tds'].to_f
			_2ago = players[i]['2ago_tds'].to_f
			_1ago = players[i]['1ago_tds'].to_f
			recenttds = (_3ago+_2ago+_1ago)/avgdivider # weekly average
			recenttds = eq_recenttds*recenttds*(@weights['recenttds'].to_f/10) # apply weight (and equalize to 1.5)
		end
		# (avg .2 ... .02)
		if (['DEF'].include? players[i]['position'])
			recenttds = players[i]['tds'].to_f/weekdivider # weekly average
			recenttds = eq_recenttds*recenttds*(@weights['recenttds'].to_f/10) # apply weight (and equalize to 1.5)
		end

		# defensive rank (avg 15 ... 1.5)
		defrank = 0
		if (['QB', 'RB', 'WR', 'TE'].include? players[i]['position'])
			defrank = players[i]['defrank'].to_f
			defrank = eq_defrank*defrank*(@weights['defrank'].to_f/10) # apply weight
		end
		
		# COMPILE 12TH MAN RATIO ----------------
		_12thmannumber = seasonpoints + recentpoints + recenttds + defrank
		
		# convert to ratio
		_12thmannumber = ((_12thmannumber / 100).round(3).to_s)[1..4]
		players[i]['12thmannumber'] = _12thmannumber
			
		# DEBUGGING
=begin
		if (players[i]['position'] == 'QB')
			puts players[i]['name']
			puts seasonpoints
			puts recentpoints
			puts recenttds
			puts defrank
			puts _12thmannumber
		end
=end
	end	
	return players
  end

  def defrankcalculation(team, week)
	opponent = getopponent(team.upcase, week-1)
	result = ''
	@defensiverank.length.times do |d|
		if (opponent == @defensiverank[d]['teamabbr'].upcase)
			result = @defensiverank[d]['rank']
		end	
	end
	return result
  end

  def getopponent(team, week)
	# !!! important - when setting the schedule make sure it matches up with the @defensiverank abbreviations
	schedule = {
		'ARI' => ['STL','DET','NO','TB','CAR','SEA','ATL','BYE','HOU','JAX','IND','PHI','STL','TEN','SEA','SF'],
		'ATL' => ['NO','STL','MIA','NE','NYJ','TB','ARI','CAR','SEA','TB','NO','BUF','GB','WAS','SF','CAR'],
		'BAL' => ['DEN','CLE','HOU','BUF','MIA','PIT','BYE','CLE','CIN','CHI','NYJ','PIT','MIN','DET','NE','CIN'],
		'BUF' => ['NE','CAR','NYJ','BAL','CLE','MIA','NO','KC','PIT','NYJ','BYE','ATL','TB','JAX','MIA','NE'],
		'CAR' => ['SEA','BUF','NYG','BYE','ARI','STL','TB','ATL','SF','NE','MIA','TB','NO','NYJ','NO','ATL'],
		'CHI' => ['CIN','MIN','PIT','DET','NO','WAS','BYE','GB','DET','BAL','STL','MIN','DAL','CLE','PHI','GB'],
		'CIN' => ['CHI','PIT','GB','CLE','NE','DET','NYJ','MIA','BAL','CLE','BYE','SD','IND','PIT','MIN','BAL'],
		'CLE' => ['MIA','BAL','MIN','CIN','BUF','GB','KC','BAL','BYE','CIN','PIT','JAX','NE','CHI','NYJ','PIT'],
		'DAL' => ['NYG','KC','STL','SD','DEN','PHI','DET','MIN','NO','BYE','NYG','OAK','CHI','GB','WAS','PHI'],
		'DEN' => ['BAL','NYG','OAK','PHI','DAL','IND','WAS','BYE','SD','KC','NE','KC','TEN','SD','HOU','OAK'],
		'DET' => ['MIN','ARI','WAS','CHI','GB','CIN','DAL','BYE','CHI','PIT','TB','GB','PHI','BAL','NYG','MIN'],
		'GB' => ['SF','WAS','CIN','BYE','DET','CLE','MIN','CHI','PHI','NYG','MIN','DET','ATL','DAL','PIT','CHI'],
		'HOU' => ['SD','TEN','BAL','SEA','SF','KC','BYE','IND','ARI','OAK','JAX','NE','JAX','IND','DEN','TEN'],
		'IND' => ['OAK','MIA','SF','JAX','SEA','DEN','BYE','HOU','STL','TEN','ARI','TEN','CIN','HOU','KC','JAX'],
		'JAX' => ['KC','OAK','SEA','IND','STL','SD','SF','BYE','TEN','ARI','HOU','CLE','HOU','BUF','TEN','IND'],
		'KC' => ['JAX','DAL','PHI','NYG','TEN','HOU','CLE','BUF','BYE','DEN','SD','DEN','WAS','OAK','IND','SD'],
		'MIA' => ['CLE','IND','ATL','NO','BAL','BUF','NE','CIN','TB','SD','CAR','NYJ','PIT','NE','BUF','NYJ'],
		'MIN' => ['DET','CHI','CLE','PIT','BYE','NYG','GB','DAL','WAS','SEA','GB','CHI','BAL','PHI','CIN','DET'],
		'NE' => ['BUF','NYJ','TB','ATL','CIN','NYJ','MIA','PIT','BYE','CAR','DEN','HOU','CLE','MIA','BAL','BUF'],
		'NO' => ['ATL','TB','ARI','MIA','CHI','BYE','BUF','NYJ','DAL','SF','ATL','SEA','CAR','STL','CAR','TB'],
		'NYG' => ['DAL','DEN','CAR','KC','PHI','MIN','PHI','BYE','OAK','GB','DAL','WAS','SD','SEA','DET','WAS'],
		'NYJ' => ['TB','NE','BUF','TEN','ATL','NE','CIN','NO','BYE','BUF','BAL','MIA','OAK','CAR','CLE','MIA'],
		'OAK' => ['IND','JAX','DEN','WAS','SD','BYE','PIT','PHI','NYG','HOU','TEN','DAL','NYJ','KC','SD','DEN'],
		'PHI' => ['WAS','SD','KC','DEN','NYG','DAL','NYG','OAK','GB','WAS','BYE','ARI','DET','MIN','CHI','DAL'],
		'PIT' => ['TEN','CIN','CHI','MIN','BYE','BAL','OAK','NE','BUF','DET','CLE','BAL','MIA','CIN','GB','CLE'],
		'SD' => ['HOU','PHI','TEN','DAL','OAK','JAX','BYE','WAS','DEN','MIA','KC','CIN','NYG','DEN','OAK','KC'],
		'SF' => ['GB','SEA','IND','STL','HOU','TEN','JAX','BYE','CAR','NO','WAS','STL','SEA','TB','ATL','ARI'],
		'SEA' => ['CAR','SF','JAX','HOU','IND','ARI','STL','TB','ATL','MIN','BYE','NO','SF','NYG','ARI','STL'],
		'STL' => ['ARI','ATL','DAL','SF','JAX','CAR','SEA','TEN','IND','BYE','CHI','SF','ARI','NO','TB','SEA'],
		'TB' => ['NYJ','NO','NE','ARI','BYE','ATL','CAR','SEA','MIA','ATL','DET','CAR','BUF','SF','STL','NO'],
		'TEN' => ['PIT','HOU','SD','NYJ','KC','SF','BYE','STL','JAX','IND','OAK','IND','DEN','ARI','JAX','HOU'],
		'WAS' => ['PHI','GB','DET','OAK','BYE','CHI','DEN','SD','MIN','PHI','SF','NYG','KC','ATL','DAL','NYG']
	}

	return schedule[team].to_a[week]
  end
end
