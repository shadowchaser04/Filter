# FILTER

Schedule youtube downloads with the YoutubeDownloader. It will look up your
browser history find all your youtube videos and download the subtitles for
each video.

## User

User will create a user based of the channel name. It will also have an
accumulated score of all videos.


## YoutubeResult

YoutubeResult will create a assosiated record to user for each video. It will
have a counted topic score and a top ten words.


## Subtitles

Subtitles is an association to the YoutubeRecord. It contains ten keys each key
is one of the topten words and has corresponding paragraphs.
