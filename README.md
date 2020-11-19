# Subtitles Downloader

The downloader uses Chrome to access your browsers history. It creates a entry for
each youtube video it finds then downloads the subtitles and json data.

## Class SubtitleDownloader

```ruby
    downloader = SubtitleDownloader.new
```

### Download the subtitles

Download the subtitles takes an argument. An Integer. How many days back in your chrome history.


    downloader.download_subtitles(2)


### Build the subtitles


    downloader.build_subtitles_hash


### Build the paragraphs

Build the paragraphs takes an argument, how many paragraph keys you want created.
All occurrences of the key will then be found, creating the paragraph's.


    downloader.build_paragraphs(3)

### Paragraph

Paragraph is a setter method that gets created from `build paragraphs` 


### Build paragraph datasets

Build the paragraph datasets, classifies each word based on topics and word
classifiers.

    
    downloader.build_paragraph_datasets(downloader.paragraph)

### Sum topics

    
    downloader.sum_topic_values(downloader.paragraph_dataset)

### Build database


