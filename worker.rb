#!/usr/bin/env ruby

#gem install nokogiri
#gem instal kramdown

require 'kramdown'
require 'open-uri'
require 'nokogiri'         

def markdown_dump(markdown_tree)
  markdown_tree.children.each_with_index do |element,index|
    print("#" + index.to_s + " " + element.inspect + "\n\n")
  end
end

def new_code_version(content_element_container, version, modification_date)
  #version_element = content_element.children[3]
  #code_url_element = version_element.children[1]
  #code_version_element = version_element.children[2]
  
  # version
  content_element_container.children[3].children[1].children[0].value = version
  
  # last updated date
  content_element_container.children[3].children[2].value = modification_date
end

def check_apple_update(url, current_version, current_modification_date)
  page = Nokogiri::HTML(open(url))    # => Nokogiri::HTML::Document
  latest_version_apple = page.css('div.zSharedSpecBoxHeadList')[0].children[0].text
  latest_version_semantic = latest_version_apple.split(',')[0][8..-1]
  latest_version_date = latest_version_apple.split(',')[1][1..-1]
  
  print("Local " + current_version + ", " + current_modification_date + " Remote " + latest_version_semantic + ", " + latest_version_date + "\n")
  
  # true if update was found, false otherwise.
  return !(current_version == latest_version_semantic) || !(current_modification_date == latest_version_date),
      latest_version_semantic,
      latest_version_date
end

def process_entry(markdown_tree, location)
  #title_element = markdown_tree.children[location]
  content_element = markdown_tree.children[location+2]

  # version
  current_version = content_element.children[3].children[1].children[0].value
  
  # modification date
  current_modification_date = content_element.children[3].children[2].value[2..-1]
  
  # upstream url
  project_url = content_element.children[3].children[1].attr["href"]
  
  is_change, latest_version, latest_date = check_apple_update(project_url, current_version, current_modification_date)
  
  if is_change
    puts "download sugarso repo from github"
    puts "download apple latest version of the code"
    puts "locally delete the latest stored version in github (don't commit, just delete it)"
    puts "move downloaded content to override the locally stored"
    puts "commit with message -- version, date change message\nAutomatic Update by http://github/sugarso/whateverpr"
    puts "Write the next markdown, overriding the existing one (same commit message)"
    puts "git push"
  end
  
  
  #new_code_version(content_element, "1983", "3-5-1983")
#  puts title_row.inspect
  #puts content_element.inspect
end

#source = open('https://raw.githubusercontent.com/sugarso/AppleSampleCode/master/README.md').read
source = open('https://raw.githubusercontent.com/maximveksler/AppleSampleCode/master/README.md').read
doc = Kramdown::Document.new(source)
root = doc.root

#markdown_dump(root)

root.children.each_with_index do |element,index|
  header_title = element.options[:raw_text]
  if header_title =~ /^\[\w+\]\[\d+\]$/
    print("Calling process for " + header_title + " at index " + index.to_s + "\n")
    process_entry(root, index)
  end
end

puts doc.to_kramdown
