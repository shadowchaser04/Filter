# Subtitles Downloader

The downloader uses Chrome to access your browsers history. It creates a entry for
each youtube videos it finds then downloads the subtitles and json data.

## Class SubtitleDownloader


    downloader = SubtitleDownloader.new


##### Download the subtitles


    downloader.download_subtitles


##### Build the Subtitles


    downloader.build_subtitles_hash


##### Build the Paragraphs

Build the Paragraphs takes an Argument, how many paragraph keys you want created.
All occurrences of the key will then be found, creating the paragraph's.


    downloader.build_paragraphs(3)

