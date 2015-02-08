require 'rubygems'
require 'rest_client'
require 'json'
require 'net/http'
require 'open-uri'
require 'nokogiri'
require 'watir-webdriver'
require 'uri'
require 'fileutils'
require 'logger'
require 'byebug'
#require 'headless'

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

#### HELP! I need somebody.
def namesafe(input)
  input.gsub!(/[^0-9A-Za-z.\-]/, '_')
  return input
end

#### Init the main class...
class ScrapingJoy
  def initialize(homedir, for_platform, prerelease = false)
    @PLATFORM = for_platform
    @HOME_PATH = File.join(homedir, @PLATFORM)
    @LIBRARY = prerelease ? 'library/prerelease' : 'library'
    @LOCAL_CACHE_PATH = File.join(@HOME_PATH, '.weed', namesafe(@LIBRARY))
    @CODE_SOURCE_FEED_URL = 'https://developer.apple.com/' + @LIBRARY + '/' + @PLATFORM.downcase + '/navigation/library.json'

    #### Make logging happen
    FileUtils.mkdir_p @LOCAL_CACHE_PATH
    log_file = File.open(@LOCAL_CACHE_PATH + '/shoutup.log', 'a')
    # noinspection RubyArgCount
    @log = Logger.new MultiDelegator.delegate(:write, :close).to(STDOUT, log_file)
  end

  def build_watir_instance(sample_code_project_home_daterev)
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['browser.download.folderList'] = 2 # custom location
    profile['browser.download.dir'] = sample_code_project_home_daterev
    profile['browser.helperApps.neverAsk.saveToDisk'] = "text/csv,application/pdf,application/zip"

    return Watir::Browser.new :firefox, :profile => profile
  end

  def kill_watir_instance(browser)
    browser.close
  end

  def attempt_booklike_page_download(browser)
    _did_download = false
    _is_deprecated = false

    begin
      # Block until page fully loaded. Not sure how this integrated Until
      # This will Watir::Wait::TimeoutError if too much time has passed. Cool right.. :)
      while (browser.li(:id, 'toc_button').when_present.style 'display' == 'none') == true
      end

      sample_code_download_url = browser.link(:id, 'Sample_link').href
      # for ex. https://developer.apple.com/library/ios/samplecode/sc1249/MotionEffects.zip -> MotionEffects.zip

      if (browser.text.include? 'This document has been removed') || (browser.text.include? 'This document has been retired')
        _is_deprecated = true
      end

      # We will try to go to the URL, and if no exception is thrown at us we will assume download was succesful?
      browser.goto(sample_code_download_url)
      _did_download = true

      return _did_download, _is_deprecated, browser.html, sample_code_download_url 
    rescue Watir::Wait::TimeoutError
      @log.error 'Error while waiting for page load. Leaving the website open for debug.'

      # begin
      #   require 'pry'
      #   binding.pry
      # rescue LoadError
      #   puts "Not loading pry"
      #   # Silent ingore debugger breakpoint if not ruby -r pry module was loaded.
      # end

      return false # success = false
    end
  end

  def scrape
    @log.debug "Scraping for #{@LIBRARY} of #{@PLATFORM}."

    #headless = Headless.new
    #headless.start

    @log.debug "Reading source #{@CODE_SOURCE_FEED_URL}"
    # Download the feed, and md5sum it's content
    json_feed_response = RestClient.get(@CODE_SOURCE_FEED_URL)
    @md5 = Digest::MD5.hexdigest(json_feed_response)

	# Compose search pattern for exiting feed json response
    signature_search_pattern = File.join(@LOCAL_CACHE_PATH, '*' + @md5 + '*.json')

    if Dir[signature_search_pattern].any?
      # IN FEED WE TRUST
      # Super Short Circuit, check if apple haven't changed the feed. If they didn't then fuck me if something changes without updating the json,
      # I'm not responsible for all the bugs in the world.
      @log.debug 'Super Fast Short Circuit. Exiting with love.'
      #log.debug "Search patterns\n#{signature_search_pattern}"
    else
      # Need to scrape, do it like a madafaker.
      parsed_feed = JSON.parse(json_feed_response)
      source_code_documents = parsed_feed.select {|document| document[2] == 5 } # 5 is "name": "Sample Code",

      __did_see_execution_errors = scrape_documents(source_code_documents)

      # Cache the finished state of the scraping job, for next execution to be super efficient.
      # Only mark as "did success" if not a single error was detected.
      _filename = namesafe(Time.now.utc.iso8601 + "-" + @md5 + ".json")
      @CACHE_FILE_NAME = File.join(@LOCAL_CACHE_PATH, _filename)
      
      if __did_see_execution_errors
        @log.debug "Will not mark #{@CACHE_FILE_NAME} as done, errors were detected during execution."
      else
        File.write(@CACHE_FILE_NAME, json_feed_response)
      end
    end

    @log.debug 'Scraping Done.'
  end

  def scrape_documents(source_code_documents)
    __did_see_execution_errors = false

    source_code_documents.each_with_index do |source_code, i|
      name = source_code[0] # "Lister: A Productivity App Built in Swift"
      id = source_code[1] # "TP40014512"
      type = source_code[2] # 5 { name: "Resource Types" { name: "Sample Code", id: "resourceType_5", sortOrder: "4", key: "5"}} // id is meaningless.
      date = source_code[3] # "2014-07-01"
      updateSize = source_code[4] # 2 { updateSize: ["First Version", "Content Update","Minor Change",""], }
      topic = source_code[5] # 1460 { name: "Topics" { name: "Languages &amp; Utilities", id: 2275, key: "1460" }} // id is meaningless.
      framework = source_code[6] # 2420 { name: "Frameworks" {name: "UIKit", id: 2213, parent: 490, key: "2420"}} // id is meaningless.
                                 # Parent: {name: "Cocoa Touch Layer", id: 2215, key: "490"} // Parent is not displayed in the HTML page apple is rending for the project
      release = source_code[7] # 157 // DON'T KNOW WHAT THIS IS ??
      subtopic = source_code[8] # 2303 { name: "Topics" { name: "Swift", id: 2325, parent: 1460, key: "2303" }} // Parent is topic (field above)
      url = source_code[9] # "../samplecode/Lister-Swift/Introduction/Intro.html#//apple_ref/doc/uid/TP40014512"
      sortOrder = source_code[10] # 0
      displayDate = source_code[11] # "2014-07-01"

      sample_code_project_home = File.join(@HOME_PATH, name)
      sample_code_project_home_daterev = File.join(sample_code_project_home, date)
      sample_code_project_home_daterev_deprecated = File.join(sample_code_project_home_daterev, '.deprecated')
      
      project_resource_fullpath = "https://developer.apple.com/#{@LIBRARY}/#{@PLATFORM.downcase}/navigation/#{ 



      }"
  	  # Shortcircut, if the zip is there, we do not redownload it.
  	  # if the project is deprecated do not redownload as well.
      scraped = Dir[File.join(sample_code_project_home_daterev, '*.zip')].any? || Dir[sample_code_project_home_daterev_deprecated].any?
      
      if not scraped
        # just stdout, no logging.
        puts "#{i.to_s}/#{source_code_documents.length} [#{name}](#{project_resource_fullpath})"

        # If  directory exits, but DATE is not that means we got update for known project project, yay!
        if File.exist?(sample_code_project_home)
          @log.info "Good news everyone! Project Update: #{sample_code_project_home}"
        else
          @log.info "Great news everyone! New Project: #{sample_code_project_home}"
        end

        # Create home directories.
        FileUtils.mkdir_p sample_code_project_home_daterev

        # Open the page once. Then attempt your best on pulling the download from that page.
        b = build_watir_instance(sample_code_project_home_daterev)
        b.goto(project_resource_fullpath)
        _did_download, _is_deprecated, html, sample_code_download_url = attempt_booklike_page_download(b)

        # # Dick factor: From WWDC 2014 apple moved *some* of the projects to the https://developer.apple.com/wwdc/resources/sample-code/ page
        # if not scrape_success
        #   scrape_success, html, sample_code_download_url, _did_download = attempt_booklike_page_download(b)
        # end

        # if not booklike_page_download and not wwdc_page_download
        #   __did_see_execution_errors = true
        # end

        # Dump the html that got us here, in case we wish to recover some more details.
        sample_html_file = File.join(sample_code_project_home_daterev, 'page.html')
        File.write(sample_html_file, html)

        # if scrape_success
        #   if not _did_download
        #     downloaded_file_name = File.basename(URI.parse(sample_code_download_url).path) # MotionEffects.zip
        #     sample_code_file = File.join(sample_code_project_home_daterev, downloaded_file_name)
        #   _did_download = download(sample_code_download_url, sample_code_file) if not _did_download
        # end

        # If we are empty on the url, mostly because apple dropped the project..
        if _did_download
          downloaded_file_name = File.basename(URI.parse(sample_code_download_url).path) # MotionEffects.zip
          if downloaded_file_name != (name + '.zip')
            @log.warn "Fuckers! Zip name: [#{downloaded_file_name}] Project name: [#{name}]"
          end

          # Finally close the browser.        
          kill_watir_instance(b)
        else
          # Check to see if it's because apple have decided to remove the file
          if _is_deprecated
            # If so, mark it so that next time we won't try to download it again (We will fail. We know nothing.)
            @log.warn "Project #{name} has been removed."
            FileUtils.touch(sample_code_project_home_daterev_deprecated)
          else
            @log.error "WTF? Scrape mojo low! :( #{name}"
            __did_see_execution_errors = true
          end
        end

        #page = Nokogiri::HTML(b.html)
        #rel_url = source_code[9]
      end
    end

    return __did_see_execution_errors
  end
end