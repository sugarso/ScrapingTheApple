#!/usr/bin/env ruby

require "rubygems"
require 'restclient'
require "json"
require 'net/http'
require 'open-uri'
require 'nokogiri'         
require 'watir-webdriver'
require 'uri'
require 'fileutils'

#require 'headless'


#### CONFIG

ROOT = "/Users/maximveksler/Desktop/apple_source_code_download"
FOR_PLATFORM='iOS' # Then switch to Mac
HOME_PATH = ROOT + "/" + FOR_PLATFORM
LOCAL_CACHE_PATH = HOME_PATH + "/" + ".weed"

URL = 'https://developer.apple.com/library/' + FOR_PLATFORM.downcase + '/navigation/library.json'


#### SETUP LOGGING
class MultiDelegator
  def initialize(*targets)
    @targets = targets
  end

  def self.delegate(*methods)
    methods.each do |m|
      define_method(m) do |*args|
        @targets.map { |t| t.send(m, *args) }
      end
    end
    self
  end

  class <<self
    alias to new
  end
end

FileUtils.mkdir_p LOCAL_CACHE_PATH
log_file = File.open(LOCAL_CACHE_PATH + "/shutup.log", "a")
log = Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, log_file)

##### DO THE SCRAPING...
log.debug "Scraping Start."

#headless = Headless.new
#headless.start

def download(source, target)
  open(target, 'wb') do |file|
    file << open(source).read
  end
end


json_feed_response = RestClient.get(URL)
md5 = Digest::MD5.hexdigest(json_feed_response)

# Super Short Circut, check if apple haven't changed the feed. If they didn't then fuck me if something changes without updating the json,
# I'm not responsible for all the bugs in the world. WE TRUST THE FEED.
if Dir[File.join(LOCAL_CACHE_PATH, '*' + md5 + '*.json')].any?
  log.debug "Super Fast Short Circut. Exiting with love."
  exit
end

parsed = JSON.parse(json_feed_response)

source_code_documents = parsed["documents"].select {|document| document[2] == 5 } # 5 is "name": "Sample Code",
source_code_documents.each_with_index do |source_code, i|
  project_name = source_code[0]
  change_date = source_code[3]
  sample_code_project_home = HOME_PATH + "/" + project_name
  sample_code_project_current = sample_code_project_home + "/" + change_date

  # Shortcircut, if the zip is there, we do not redownload it.
  if Dir[File.join(sample_code_project_current, '*.zip')].empty? == true
    #https://developer.apple.com/library/ios/samplecode/sc1249/MotionEffects.zip
    #https://developer.apple.com/library/ios/samplecode/Tabster/Tabster.zip
    #https://developer.apple.com/library/ios/samplecode/CryptoExercise/CryptoExercise.zip
    #https://developer.apple.com/library/ios/samplecode/ZoomingPDFViewer/ZoomingPDFViewer.zip

  #      [
  #          "MotionEffects",
  #          "DTS40014521",
  #          5,
  #          "2014-05-14",
  #          0,
  #          2470,
  #          2420,
  #          133,
  #          0,
  #          "../samplecode/sc1249/Introduction/Intro.html#//apple_ref/doc/uid/DTS40014521",
  #          0,
  #          "2014-05-14"
  #      ],
  #
  #
  #"columns": {
  #      "name": 0,
  #      "id": 1,
  #      "type": 2,
  #      "date": 3,
  #      "updateSize": 4,
  #      "topic": 5,
  #      "framework": 6,
  #      "release": 7,
  #      "subtopic": 8,
  #      "url": 9,
  #      "sortOrder": 10,
  #      "displayDate": 11
  #  },
  #
    b = Watir::Browser.new
    b.goto("https://developer.apple.com/library/" + FOR_PLATFORM.downcase + "/navigation/" + source_code[9])
    # Block until page fully loaded.
    while (b.li(:id, 'toc_button').when_present.style "display" == "none") == true
    end
  
    #puts b.li(:id, 'toc_button').when_present.style "display" #block until stupid apple JS is loaded.
    sample_code_download_url = b.link(:id, 'Sample_link').href
    downloaded_file_name = File.basename(URI.parse(sample_code_download_url).path)
    
    sample_code_file = sample_code_project_current + "/" + downloaded_file_name
    sample_html_file = sample_code_project_current + "/" + "page.html"
    
    if ! File.file?(sample_code_file)
      
      puts "Position = " + i.to_s + "/#{source_code_documents.length}"
      # If the directory exits, but the date is not this means we got (hopefully) a new date, yay!
      if File.exist?(sample_code_project_home)
        log.info "Good news everyone! Project Update: " + project_name + "/" + change_date + "/" + downloaded_file_name
      else
        log.info "Great news everyone! New Project: " + project_name + "/" + change_date + "/" + downloaded_file_name
      end
      
      if downloaded_file_name != (project_name + ".zip")
        log.warn "Fuckers! Zip name: [" + downloaded_file_name + "] Project name: [" + project_name + "]"
      end
      
      # Dump the html that got us here, in case we with to recover the more details.
      # Use html page name here, becaues why the fuck not?! (Just kidding, html name is always present)
      FileUtils.mkdir_p File.dirname(sample_html_file)
      File.write(sample_html_file, b.html)
  
      # If we are empty on the url, mostly because apple dropped the project..
      if sample_code_download_url.to_s == ''
        # Check to see if it's because apple have decided to remove the file
        if b.html.include? "This document has been removed"
          log.warn "Project " + project_name + " has been removed."
        else
          log.error "WTF!!! Can't scrpae :(" + project_name
        end
      else
        download(sample_code_download_url, sample_code_file)
      end
    end
  
    #page = Nokogiri::HTML(b.html)   
    #rel_url = source_code[9]
    
    # Finally close the browser.
    b.close
  end
end

# Cache the finished state of the scraping job, for next execution to be super effiecient.
CACHE_FILE_NAME=Time.now.utc.iso8601 + "-" + md5 + ".json"
File.write(LOCAL_CACHE_PATH + "/" + CACHE_FILE_NAME, json_feed_response)
log.debug "Scraping Done."