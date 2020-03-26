require 'discordrb'
require 'mysql2'
require 'json'

#json config in newgir.json
# {
	# "token" : "NNNNNNNNAAAAAAAjj",
	# "sql": 
	# {
	# "host" : "localhost",
	# "user" : "dunce",
	# "password" : "lifesucks",
	# "database" : "irc"
	# }
# }

configFile = File.read("newgir.json")
config = JSON.parse(configFile)


bot = Discordrb::Bot.new token: config["token"]
$client = Mysql2::Client.new(:host => config["sql"]["host"], 
							 :username => config["sql"]["user"], 
							 :password => config["sql"]["password"], 
							 :database => config["sql"]["database"])
$VERSION = "0.26"
#get line min and max

def query(q)
	puts "Executing #{q}"
	results = $client.query(q)
	return results
end

def getRule(n, channel="#vancouver-free")
	res = query("SELECT description FROM rules WHERE rulenumber='#{n}' AND channel='#{channel}'")
	if res.count > 0
		res.each do |row|
			return row
		end
	else
		return false
	end
end

def getDefinition(k, channel="#vancouver-free")
	#get the latest definition by definitionid
	res = query("SELECT channel,keyword,description,definitionid FROM definitions WHERE CHANNEL='#{channel}' AND keyword='#{k}' ORDER BY definitionid DESC LIMIT 3")
	if res.count > 0
		ret = []
		res.each do |row|
			ret.push(row.values[2])
		end
		return ret
	else
		return false
	end
end

def setDefinition(k,v, channel="#vancouver-free")
	res = query("INSERT INTO definitions (channel,keyword,description) VALUES ('#{channel}', '#{k}', '#{v}')")
	#just pile them on, get the latest one in get
end

def getLineMinimum()
	res = query("SELECT MIN(linenumber) FROM irclog")
	res.each do |row|
		puts "Minimum: #{row["MIN(linenumber)"]}"
		return row["MIN(linenumber)"]
	end
end

def getLineMaximum()
	res = query("SELECT MAX(linenumber) FROM irclog")
	res.each do |row|
		puts "Maximum: #{row["MAX(linenumber)"]}"
		return row["MAX(linenumber)"]
	end
end

def getRandomLineNumber()
	return rand(getLineMinimum()...getLineMaximum())
end

def getRandomLineByNick(nick)
	while true
		line = getRandomLineNumber()
		res = query("SELECT nick,log,datetime FROM irclog WHERE linenumber > #{line} AND nick='#{nick}'")
		if res.count > 0
			res.each do |row|
				return row
			end
		end
	end
end

def getRandomLine()
	#we loop until we find a good line
	#linenumber is not guaranteed to be contiguous
	while true
		line = getRandomLineNumber()
		puts "Random Line: #{line}"
		res = query("SELECT nick,log,datetime FROM irclog WHERE linenumber=#{line}")
		if res.count > 0
			res.each do |row|
				return row
			end
		end
	end
end

def action(n)
	return "_#{n}_"
end
	

bot.message(start_with: '!quote') do |event|
	args = event.message.content.split(' ', 2)
	#args[0] = !quote
	#args[1] = nickname
	res = false
	puts "ARgs length: #{args.length}"
	if args.length == 2
		res = getRandomLineByNick(args[1])
	else 
		res = getRandomLine()
	end
	resp = "<#{res.values[0]}/#{res.values[2]}> #{res.values[1]}"
	event.respond resp
end

bot.message(start_with: '!analrape') do |event|
	args = event.message.content.split(' ', 2)
	resp = action("Pretends he's a priest and #{args[1]} is a nine year old boy!!")
	event.respond resp
end

bot.message() do |event|
	puts "Message: #{event.message.content}"
end

bot.message(start_with: '!rule') do |event|
	args = event.message.content.split(' ', 2)
	rule = getRule(args[1])
	if rule != false
		event.respond("Channel Rule #{args[1]}: #{rule.values[0]}")
	else
		event.respond("Channel rule #{args[1]} not found!")
	end
end

bot.message(start_with: '!set') do |event|
	args = event.message.content.split(' ', 3)
	#args[0] = !set
	#args[1] = keyword
	#args[2] = values
	puts "Args length is #{args.length}"
	if args.length == 2
		#get the values
		defn = getDefinition(args[1])
		if defn != false
			defn.each do |adef| 
				resp = "[#{args[1]}] #{adef}"
				event.respond resp
			end
		end
	else
		#update
		resp = setDefinition(args[1], args[2])
	end
end

puts "NewGir (Reverend Doctor Occupant) #{$VERSION}"

if ARGV.include?("--daemon")
	puts "Detaching..."
	Process.daemon()
end

bot.run