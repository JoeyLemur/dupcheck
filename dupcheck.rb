require 'find'
require 'digest'
require 'sqlite3'

# Used when storing database
DBNAME = "dupcheck.db"

# First argument is a directory to start searching at
startPoint = ARGV[0]
if startPoint.nil? then
  STDERR.puts "Feed me a start directory!"
  Kernel.exit(1)
end

# Second (or more) are dot-extensions (case-insensitive) to look for
extensions = ARGV[1..-1]
if extensions.nil? or extensions.empty? then
  STDERR.puts "Feed me extensions!"
  Kernel.exit(1)
end
extensions.map! { |i| i.downcase }

# Mark when we start
startTime = Time.now

# Open database
db = SQLite3::Database.new(':memory:')
#File.delete(DBNAME) if File.exist?(DBNAME)
#db = SQLite3::Database.new(DBNAME)

# Set up table, index, and insert statement
db.execute 'CREATE TABLE files (origPath string, fileName string, size integer, ctime integer, mtime integer, digest string)'
db.execute 'CREATE INDEX idx_files_digest on files(digest)'
insertStmt = db.prepare("insert into files (origPath,fileName,size,ctime,mtime,digest) values (?,?,?,?,?,?)")

# Counter for directory entry count and found entry count
entryCount = 0
foundCount = 0

# Start finding all files on our start path
Find.find(startPoint) do |path|
  # Increment entryCount, report sometimes
  entryCount += 1
  STDERR.puts "#{Time.now} - #{foundCount} / #{entryCount}" if entryCount % 100000 == 0
  
  # Skip if its not file
  next if not File.file?(path)
  
  # Try to get the extension of the file, skip if there isn't one
  ext = path.split('.')[-1]
  next if ext.nil?
  # Downcase the extension, and skip if its not on our list
  ext.downcase!
  next if extensions.index(ext).nil?
  
  # Increment found count
  foundCount += 1
  
  # Compute needed data
  shortName = File.basename(path)
  fileSize = File.size(path)
  ctime = File.ctime(path).to_i
  mtime = File.mtime(path).to_i
  fileDigest = Digest::SHA256.file(path).hexdigest
  
  # Insert into database
  insertStmt.execute(path,shortName,fileSize,ctime,mtime,fileDigest)
end

# Final report
STDERR.puts "#{Time.now} - #{foundCount} / #{entryCount} (DONE)"

# Wait a second for the database to catch up... this isn't optimal...
sleep(1)

# Count of how many wasted bytes
wastedBytes = 0

# Storage for duplicate reports
duplicates = []

# Get what digests have more than one entry and store
results = db.execute('select digest, count(*) as c from files group by digest having c > 1')
results.each do |r|
  t = []
  entries = db.execute('select origPath,size from files where digest=?',r[0])
  fileSize = entries[0][1].to_i   # Get the file size
  entries.each { |s| t << s[0] }  # Put the path in to the array
  wastedBytes += fileSize * (t.count-1)  # Calculate wasted bytes
  duplicates << t  # Store duplicates array
end

# Report duplicates
duplicates.sort.each do |i|
  puts "-----"
  i.each { |j| puts j }
end

# Cleanup and report
STDERR.puts <<-EOS

     Start time: #{startTime}
       End time: #{Time.now}
  Files checked: #{entryCount}
Duplicate files: #{duplicates.count}
   Wasted bytes: #{wastedBytes}
EOS

