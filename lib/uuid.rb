#
# = uuid.rb - UUID generator
#
# Author:: Assaf Arkin  assaf@labnotes.org
#          Eric Hodel drbrain@segment7.net
# Copyright:: Copyright (c) 2005-2010 Assaf Arkin, Eric Hodel
# License:: MIT and/or Creative Commons Attribution-ShareAlike

require 'fileutils'
require 'thread'
require 'tmpdir'

require 'rubygems'
require 'macaddr'
require 'base62'
require 'scanf'

##
# = Generating UUIDs
#
# Call #generate to generate a new UUID. The method returns a string in one of
# three formats. The default format is 36 characters long, and contains the 32
# hexadecimal octets and hyphens separating the various value parts. The
# <tt>:compact</tt> format omits the hyphens, while the <tt>:urn</tt> format
# adds the <tt>:urn:uuid</tt> prefix.
#
# For example:
#
#   uuid = UUID.new
#   
#   10.times do
#     p uuid.generate
#   end
#
# = UUIDs in Brief
#
# UUID (universally unique identifier) are guaranteed to be unique across time
# and space.
#
# A UUID is 128 bit long, and consists of a 60-bit time value, a 16-bit
# sequence number and a 48-bit node identifier.
#
# The time value is taken from the system clock, and is monotonically
# incrementing.  However, since it is possible to set the system clock
# backward, a sequence number is added.  The sequence number is incremented
# each time the UUID generator is started.  The combination guarantees that
# identifiers created on the same machine are unique with a high degree of
# probability.
#
# Note that due to the structure of the UUID and the use of sequence number,
# there is no guarantee that UUID values themselves are monotonically
# incrementing.  The UUID value cannot itself be used to sort based on order
# of creation.
#
# To guarantee that UUIDs are unique across all machines in the network,
# the IEEE 802 MAC address of the machine's network interface card is used as
# the node identifier.
#
# For more information see {RFC 4122}[http://www.ietf.org/rfc/rfc4122.txt].

class UUID

  # Version number.
  module Version
    version = Gem::Specification.load(File.expand_path("../gn0m30-uuid.gemspec", File.dirname(__FILE__))).version.to_s.split(".").map { |i| i.to_i }
    MAJOR = version[0]
    MINOR = version[1]
    PATCH = version[2]
    STRING = "#{MAJOR}.#{MINOR}.#{PATCH}"
  end

  VERSION = Version::STRING

  ##
  # Clock multiplier. Converts Time (resolution: seconds) to UUID clock
  # (resolution: 10ns)
  CLOCK_MULTIPLIER = 10000000

  ##
  # Clock gap is the number of ticks (resolution: 10ns) between two Ruby Time
  # ticks.
  CLOCK_GAPS = 100000

  ##
  # Version number stamped into the UUID to identify it as time-based.
  VERSION_CLOCK = 0x0100

  ##
  # Formats supported by the UUID generator.
  #
  # <tt>:default</tt>:: Produces 36 characters, including hyphens separating
  #                     the UUID value parts
  # <tt>:compact</tt>:: Produces a 32 digits (hexadecimal) value with no
  #                     hyphens
  # <tt>:urn</tt>:: Adds the prefix <tt>urn:uuid:</tt> to the default format
  # <tt>:teenie</tt>:: converts numeric portions of default format to base62
  FORMATS = {
    :compact => '%08x%04x%04x%04x%012x',
    :default => '%08x-%04x-%04x-%04x-%012x',
    :urn     => 'urn:uuid:%08x-%04x-%04x-%04x-%012x',
    :teenie  => '%6.6s%3.3s%3.3s%3.3s%9.9s',
  }

  ##
  # MAC address (48 bits), sequence number and last clock
  STATE_FILE_FORMAT = 'SLLQ'

  @state_file = nil
  @mode = nil
  @uuid = nil

  ##
  # The access mode of the state file.  Set it with state_file.

  def self.mode
    @mode
  end

  ##
  # Generates a new UUID string using +format+.  See FORMATS for a list of
  # supported formats.

  def self.generate(format = :default)
    @uuid ||= new
    @uuid.generate format
  end

  ##
  # Creates an empty state file in /var/tmp/ruby-uuid or the windows common
  # application data directory using mode 0644.  Call with a different mode
  # before creating a UUID generator if you want to open access beyond your
  # user by default.
  #
  # If the default state dir is not writable, UUID falls back to ~/.ruby-uuid.
  #
  # State files are not portable across machines.
  def self.state_file(mode = 0644)
    return @state_file unless @state_file.nil?

    @mode = mode

    begin
      require 'Win32API'

      csidl_common_appdata = 0x0023
      path = 0.chr * 260
      get_folder_path = Win32API.new('shell32', 'SHGetFolderPath', 'LLLLP', 'L')
      get_folder_path.call 0, csidl_common_appdata, 0, 1, path

      state_dir = File.join(path.strip)
    rescue LoadError
      state_dir = File.join('', 'var', 'tmp')
    end

    if File.writable?(state_dir) then
      @state_file = File.join(state_dir, 'ruby-uuid')
    else
      @state_file = File.expand_path(File.join('~', '.ruby-uuid'))
    end

    @state_file
  end

  ##
  # Specify the path of the state file.  Use this if you need a different
  # location for your state file.
  #
  # Set to false if your system cannot use a state file (e.g. many shared
  # hosts).
  def self.state_file=(path)
    @state_file = path
  end

  ##
  # Returns true if +uuid+ is in compact, default or urn formats.  Does not
  # validate the layout (RFC 4122 section 4) of the UUID.
  # does not validate :teenie format. see validate_teenie
  def self.validate(uuid)
    return true if uuid =~ /\A[\da-f]{32}\z/i
    return true if
      uuid =~ /\A(urn:uuid:)?[\da-f]{8}-([\da-f]{4}-){3}[\da-f]{12}\z/i
  end

  ##
  # Returns true if +uuid+ is in teenie format
  def self.validate_teenie(uuid)
    return true if uuid =~ /\A[\da-fA-f]{24}\z/i
  end

  ##
  # translate one format uuid to another
  def self.translate(uuid, source_format, target_format)
    if source_format == :teenie
      raise "invalid uuid passed in for translation" unless UUID.validate_teenie(uuid)
    else
      raise "invalid uuid passed in for translation" unless UUID.validate(uuid)
    end

    raise "invalid source format passed in for tranlation" unless FORMATS[source_format]
    raise "invalid target format passed in for tranlation" unless FORMATS[target_format]
    raise "it's a waste of time to translate one format to another" unless source_format != target_format

    parts = Array.new
    
    if source_format != :teenie
      parts = uuid.scanf(FORMATS[source_format])
    else
      # this has to stay in synch with the :teenie format
      parts[0] = uuid[0..5].base62_decode
      parts[1] = uuid[6..8].base62_decode
      parts[2] = uuid[9..11].base62_decode
      parts[3] = uuid[12..14].base62_decode
      parts[4] = uuid[15..23].base62_decode
    end

    @uuid ||= new
    @uuid.generate_from_parts(target_format, parts[0], parts[1], parts[2], parts[3], parts[4])
  end
  
  ##
  # Create a new UUID generator.  You really only need to do this once.
  def initialize
    @drift = 0
    @last_clock = (Time.now.to_f * CLOCK_MULTIPLIER).to_i
    @mutex = Mutex.new

    state_file = self.class.state_file
    if state_file && File.size?(state_file) then
      next_sequence
    else
      @mac = Mac.addr.gsub(/:|-/, '').hex & 0x7FFFFFFFFFFF
      fail "Cannot determine MAC address from any available interface, tried with #{Mac.addr}" if @mac == 0
      @sequence = rand 0x10000

      if state_file
        open_lock 'w' do |io|
          write_state io
        end
      end
    end
  end

  ##
  # Generates a new UUID string using +format+.  See FORMATS for a list of
  # supported formats.
  def generate(format = :default)

    # The clock must be monotonically increasing. The clock resolution is at
    # best 100 ns (UUID spec), but practically may be lower (on my setup,
    # around 1ms). If this method is called too fast, we don't have a
    # monotonically increasing clock, so the solution is to just wait.
    #
    # It is possible for the clock to be adjusted backwards, in which case we
    # would end up blocking for a long time. When backward clock is detected,
    # we prevent duplicates by asking for a new sequence number and continue
    # with the new clock.

    clock = @mutex.synchronize do
      clock = (Time.new.to_f * CLOCK_MULTIPLIER).to_i & 0xFFFFFFFFFFFFFFF0

      if clock > @last_clock then
        @drift = 0
        @last_clock = clock
      elsif clock == @last_clock then
        drift = @drift += 1

        if drift < 10000 then
          @last_clock += 1
        else
          Thread.pass
          nil
        end
      else
        next_sequence
        @last_clock = clock
      end
    end until clock

    part1 = clock & 0xFFFFFFFF
    part2 = (clock >> 32) & 0xFFFF
    part3 = ((clock >> 48) & 0xFFFF | VERSION_CLOCK)
    part4 = @sequence & 0xFFFF
    part5 = @mac & 0xFFFFFFFFFFFF

    generate_from_parts(format, part1, part2, part3, part4, part5)
  end

  ##
  # Updates the state file with a new sequence number.
  def next_sequence
    if self.class.state_file
      open_lock 'r+' do |io|
        @mac, @sequence, @last_clock = read_state(io)

        io.rewind
        io.truncate 0

        @sequence += 1

        write_state io
      end
    else
      @sequence += 1
    end
  rescue Errno::ENOENT
    open_lock 'w' do |io|
      write_state io
    end
  ensure
    @last_clock = (Time.now.to_f * CLOCK_MULTIPLIER).to_i
    @drift = 0
  end

  def inspect
    mac = ("%012x" % @mac).scan(/[0-9a-f]{2}/).join(':')
    "MAC: #{mac}  Sequence: #{@sequence}"
  end

  ##
  # this is used both for generation and translation
  def generate_from_parts(format, part1, part2, part3, part4, part5)

    template = FORMATS[format]

    raise ArgumentError, "invalid UUID format #{format.inspect}" unless template

    # for this special case, the parts are going to be strings which we will 0 pad
    if format == :teenie
      part1 = part1.base62_encode
      part2 = part2.base62_encode
      part3 = part3.base62_encode
      part4 = part4.base62_encode
      part5 = part5.base62_encode

      (template % [part1, part2, part3, part4, part5]).gsub(' ', '0')
    else
      template % [part1, part2, part3, part4, part5]
    end
  end
  
protected

  ##
  # Open the state file with an exclusive lock and access mode +mode+.
  def open_lock(mode)
    File.open self.class.state_file, mode, self.class.mode do |io|
      begin
        io.flock File::LOCK_EX
        yield io
      ensure
        io.flock File::LOCK_UN
      end
    end
  end

  ##
  # Read the state from +io+
  def read_state(io)
    mac1, mac2, seq, last_clock = io.read(32).unpack(STATE_FILE_FORMAT)
    mac = (mac1 << 32) + mac2

    return mac, seq, last_clock
  end


  ##
  # Write that state to +io+
  def write_state(io)
    mac2 =  @mac        & 0xffffffff
    mac1 = (@mac >> 32) & 0xffff

    io.write [mac1, mac2, @sequence, @last_clock].pack(STATE_FILE_FORMAT)
  end

end
