
require 'net/http'
require 'hpricot'

module ThesaurusDotCom
  BASE_URL = "http://www.thesaurus.com/browse/"
  ANTONYMS_PATH = "//section[@class='container-info antonyms']/div/ul/li/a/span/text()"

  def get_antonyms word
     url = "#{BASE_URL}#{word}?s=t"

     uri = URI.parse(url)

     result = Net::HTTP.start(uri.host, uri.port) { |http| http.read_timeout = 60; http.get(uri.path) }

     return nil if result.code.to_i > 400

     doc = Hpricot(result.body)
     return doc.search(ANTONYMS_PATH)
  end
end
