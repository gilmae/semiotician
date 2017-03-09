require 'net/http'
require 'rvg/rvg'
require 'hpricot'
require 'yaml'
require 'mail'
require 'twitter'
require 'fileutils'

include Magick

def get_an_antonym word
  p "Look for antonym for #{word}"
  url = "http://www.thesaurus.com/browse/#{word}?s=t"

  uri = URI.parse(url)

  result = Net::HTTP.start(uri.host, uri.port) { |http| http.read_timeout = 60; http.get(uri.path) }

  return nil if result.code.to_i > 400

  doc = Hpricot(result.body)
  antonyms = doc.search("//section[@class='container-info antonyms']/div/ul/li/a/span/text()")
  return (antonyms[rand() * antonyms.length]) if antonyms
  nil
end

def generate_semes adjectives
  seme = nil
  contradictory_seme = nil
  failed_semes = []
  until contradictory_seme
    seme = find_seme adjectives
    contradictory_seme = get_an_antonym seme
    (failed_semes << seme) unless contradictory_seme
  end

  return seme, contradictory_seme, failed_semes
end


def find_seme semes
  index = rand() * semes.length
  seme = semes[index]

  return seme
end

def draw_square seme1,contradictory_seme1, seme2, contradictory_seme2, path

  rvg = RVG.new(7.in, 7.in).viewbox(0,0,500,400) do |canvas|
    canvas.background_fill = 'white'

    # Draw Contrary Lines
    canvas.line(125, 90, 350, 90).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4])
    canvas.line(125, 290, 350, 290).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4])

    # Draw contradictory lines
    canvas.line(125, 95, 350, 285).styles(:stroke_width=>2, :stroke=>'black')
    canvas.line(350, 95, 125, 285).styles(:stroke_width=>2, :stroke=>'black')

    # Draw implication lines
    canvas.line(125, 110, 125, 280).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4,1,4])
    canvas.line(350, 110, 350, 280).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4,1,4])

    canvas.polygon(120,110, 125,100, 130,110).styles(:stroke_width=>1, :stroke=>'black')
    canvas.polygon(345,110, 350,100, 355,110).styles(:stroke_width=>1, :stroke=>'black')

    canvas.text(60, 75, seme1).styles(:font_size=>14, :fill=>'black')
    canvas.text(360, 75, seme2).styles(:font_size=>14, :fill=>'black')
    canvas.text(60, 325, contradictory_seme2).styles(:font_size=>14, :fill=>'black')
    canvas.text(360, 325, contradictory_seme1).styles(:font_size=>14, :fill=>'black')
  end

  rvg.draw.write(path)
end


# Let's start

# One day I really should find out what a non-72 DPI implies
RVG::dpi = 72

# Loading config, and dying if no config
config_file = File.expand_path(File.dirname(__FILE__)) + '/.config'

if File.exists? config_file
  config = File.open(config_file, 'r') do|f|
    config = YAML.load(f.read)
  end
end

if !config
  p "Missing config file"
  exit
end

base_path = config["squares"]

square_path = "#{base_path}square_#{Time.now.strftime("%Y%m%d%H")}.png"

# Ok, so if there is already a square waiting for me to fill in, just die
#exit if File.exists?(SQUARE_PATH)

# Still here? Ok, load our adjectives

adjectives = []
File.open(config["semes"], "r") do |f|
   adjectives = f.read.split("\n")
end
p "#{adjectives.length} words to chose from"

# Create a square, generate the semes, and draw it out.
seme, not_seme, failed_semes = generate_semes adjectives
seme2, not_seme2, failed_semes = generate_semes adjectives

draw_square seme, not_seme, seme2, not_seme2, square_path

# And write the semes back out after all the semes that failed to have antonyms are removed
File.open(config["semes"], "w") do |f|
   f << adjectives.join("\n")
end

if config["twitter"]
  client = Twitter::REST::Client.new do |twitter|
    twitter.consumer_key = config["twitter"]["CONSUMER_KEY"]
    twitter.consumer_secret = config["twitter"]["CONSUMER_SECRET"]
    twitter.access_token = config["twitter"]["OAUTH_TOKEN"]
    twitter.access_token_secret = config["twitter"]["OAUTH_TOKEN_SECRET"]
  end

  File.open(square_path, "r") do |file|
    client.update_with_media("", file)
  end
end

if config["smtp"]
  Mail.defaults do
    delivery_method :smtp, Hash[config["smtp"].map{|k,v| [k.to_sym, v]}]
  end

  Mail.deliver do
    from 'avocadia@fastmail.fm'
    to 'avocadia@fastmail.fm'
    subject 'Another Semiotic Square'
    body 'Enjoy'
    add_file square_path
  end
end

FileUtils.rm(square_path)
