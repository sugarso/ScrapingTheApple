require_relative 'scraping_joy'

ROOT = '/Volumes/Macintosh SD/apple_source_code_download'

# ios_samples_scraper = ScrapingJoy.new(ROOT, 'iOS', prerelease=true)
# ios_samples_scraper.scrape()

ios_samples_scraper = ScrapingJoy.new(ROOT, 'iOS')
ios_samples_scraper.scrape()

# ios_samples_scraper = ScrapingJoy.new(ROOT, 'Mac', prerelease=true)
# ios_samples_scraper.scrape()

ios_samples_scraper = ScrapingJoy.new(ROOT, 'Mac')
ios_samples_scraper.scrape()
