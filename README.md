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

To navigate through the menus, use the arrow keys to move through options and press `ENTER` to select an option. Alternatively, you can use `[0-9]` to select options but not with double digit options.

Upon entering the main menu, enter a bucket name (if not already provided as an argument) and double check your profile/region at the main menu. Once everything is all set, enter the bucket to navigate through bucket contents.

While navigating the bucket, selecting a folder will allow you to enter that folder and view its contents. When selecting a file, the user will be able to download the file with a new name (if desired).

This program utilizes Shopify's [cli-ui](https://github.com/Shopify/cli-ui) gem. A handy built-in feature of this gem is filtering on options. Whenever presented with options, try pressing `F` and typing in an option and the list will be filtered for you!

## Homebrew Formula

Check out the homebrew formula in [my other repository](https://github.com/seamus-sloan/homebrew-tools) for other tools.

## Future Improvements

- [ ] Ensure downloaded files have the correct extension
- [ ] Allow for downloading entire folders
- [ ] Allow for moving files around within a bucket
- [ ] Add additional options for configuring new profiles
