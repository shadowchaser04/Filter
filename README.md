# Subtitles Downloader

The downloader uses Chrome to access your browsers history. It creates a entry for
each youtube video it finds then downloads the subtitles and json data.

## Class SubtitleDownloader

```ruby
    downloader = SubtitleDownloader.new
```

### Download the subtitles

Download the subtitles access's Chromes browser history. Filtering all youtube
video urls and downloading them. It takes an argument, how many days back in
your history do you want to retrieve.


    downloader.download_subtitles(2)

#### return value: filepaths

Filepaths is an `setter method Hash` consisting of a primary Key: `title` and
secondary nested keys `json`, and `vtt`. Each of which point to there absolute file
path location.


### Build the subtitles


    downloader.build_subtitles_hash

#### return value: subtitles

Subtitles is a `setter method Hash` consisting of a primary Key: `title` which is
the youtube video title and a Value: `words array`. Which is an array of single
words.


### Build the paragraphs

Build the paragraphs takes an argument, how many paragraph keys you want created.
All occurrences of the key will then be found, creating the paragraph's.


    downloader.build_paragraphs(3)

### return value: paragraphs

Paragraph is a `setter method Hash` that gets created from `build paragraphs`.
It takes an argument, how many paragraph keys to retrieve. Each key found is
derived from the top counted words specific to each youtube videos subtitles. 


### Build paragraph datasets

Build the paragraph datasets, classifies each word based on topics and word
classifiers.


    downloader.build_paragraph_datasets(downloader.paragraph)

### Sum topics


    downloader.sum_topic_values(downloader.paragraph_dataset)

### Build database


    downloader.build_database(downloader.paragraph_dataset)

### Total user


    downloader.total_users


