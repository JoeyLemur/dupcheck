# DupCheck

So, I found myself with many years worth of USB backup drives and nested 'Old Home Directory' directories, with an absurd number of duplicated files.  I hacked together this tool to help me find the redundancies that could be deleted to save space, and make managing the rats-nest more managable.

## Requirements

- Developed on Ruby 2.5.1, should work with anything of 2.x vintage.
- Requires the sqlite3 gem

## Usage

`ruby dupcheck.rb <path> [<extension> ...]`
  
Example: `ruby dupcheck.rb /path/to/dir jpg jpeg`

## How it works

It uses Ruby's `File.find` from the provided path to search for directory entries, skipping over items that are not files.  It then splits the file name by '.' and case-insensitive checks the extension of the file, skipping it if it isn't part of the (again, case-insensitive) provided extensions in the command line.  When a matching file is found, it generates a SHA256 hash and collects the file size, ctime, and mtime, and stores it in a SQLite3 database.

After the `File.find` is complete, the database is queried for multiple entries with the same SHA256 hash.  These are grouped together and written to STDIN, for piping out to a file for later analysis.

The output is a seperator line, followed by a line of the SHA256 hash, and then tab-delimited entries for each file: path, file size, ctime, mtime

## Support

Bwahahahaha.  This is not a production ready tool.  It works well enough for me, and I like to think the source code is readable enough for anyone with passing familiarity with Ruby.
 