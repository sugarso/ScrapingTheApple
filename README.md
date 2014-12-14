ScrapingTheApple
================

Behind the scenes robot for https://github.com/sugarso/AppleSampleCode


DO THIS 
=======

Steps to commit a project revision to https://github.com/sugarso/AppleSampleCode (manual - to be automation sometime in the future)...

1. ```git up``` the latest version of http://github.com/sugarso/AppleSampleCode
2. ```cd ~/Developer/ScrapingTheApple/```
3. Make sure ```ROOT = '/Volumes/Macintosh SD/apple_source_code_download'``` in ScrapeThemAll.rb points to a good location on your disk
3. Run ```ruby ScrapeThemAll.rb``` (fix all the ```require``` and stuff, or wait for me to do it someday)
4. Expect which new version of files have downloaded. Intersting locations are ```/Volumes/Macintosh SD/apple_source_code_download/Mac/.weed/*json``` and ```/Volumes/Macintosh SD/apple_source_code_download/iOS/.weed/*json``` where you can take 2 files and view them with **Kaleidoscope** to understand what documentation apple have been focusing on lately.
5. Read ```/Volumes/Macintosh SD/apple_source_code_download/iOS/.weed/*json```
