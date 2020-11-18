# Subtitles Downloader

The downloader uses Chrome to access your browsers history. It creates a entry for
each youtube video it finds then downloads the subtitles and json data.

## Class SubtitleDownloader


    downloader = SubtitleDownloader.new


#### Download the subtitles

Download the subtitles takes an argument. An Integer. How many days back in your chrome history.


    downloader.download_subtitles(2)


#### Build the Subtitles


    downloader.build_subtitles_hash


#### Build the Paragraphs

Build the paragraphs takes an argument, how many paragraph keys you want created.
All occurrences of the key will then be found, creating the paragraph's.


    downloader.build_paragraphs(3)

