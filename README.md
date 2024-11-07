# SS3 (AWS S3 Bucket Tool)

`ss3` is an interactive CLI tool to help users navigate through the contents of different S3 buckets and download their contents easily.

## Installation

```sh
brew install seamus-sloan/tools/ss3

# You may need this if not installed already...
brew install awscli
```

If you'd prefer to not use homebrew, making the script run through an alias (`ss3`) in your terminal profile is preferred. Ensure that the helper files remain adjacent to the main `aws-s3-bucket-tool` script.

## Usage

```sh
ss3 [optional_bucket_name]
```

If no bucket name is entered, the user will be able to enter a bucket name and attempt to connect to it.

If there are any errors while attempting to connect to a bucket, you can press `P` or `R` at this menu to switch your AWS Profile or AWS Region respectively and try again.

Once connected to a bucket, use the `[0 - 9]` keys to make selections on items within the bucket.

If the selected item is a folder, `ss3` will navigate you inside of that folder. If the selected item is a file, `ss3` will prompt you to download the file.

While traversing through the bucket, you can easily go back (`[B]`) or enter a new bucket name (`[N]`) to switch to a different bucket.
