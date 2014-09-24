require_relative 'scraping_joy'

ROOT = '/Volumes/Macintosh SD/apple_source_code_download'

ScrapingJoy.new(ROOT, 'Mac').scrape()
ScrapingJoy.new(ROOT, 'iOS').scrape()

ScrapingJoy.new(ROOT, 'Mac', prerelease=true).scrape()
ScrapingJoy.new(ROOT, 'iOS', prerelease=true).scrape()
