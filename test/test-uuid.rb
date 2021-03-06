# Author:: Assaf Arkin  assaf@labnotes.org
#          Eric Hodel drbrain@segment7.net
# Copyright:: Copyright (c) 2005-2008 Assaf Arkin, Eric Hodel
# License:: MIT and/or Creative Commons Attribution-ShareAlike

require 'test/unit'
require 'uuid'

class TestUUID < Test::Unit::TestCase

  def test_state_file_creation
    path = UUID.state_file
    File.delete path if File.exist?(path)
    UUID.new.generate
    File.exist?(path)
  end

  def test_state_file_specify
    path = File.join("path", "to", "ruby-uuid")
    UUID.state_file = path
    assert_equal path, UUID.state_file
  end

  def test_with_no_state_file
    UUID.state_file = false
    assert !UUID.state_file
    uuid = UUID.new
    assert_match(/\A[\da-f]{32}\z/i, uuid.generate(:compact))
    seq = uuid.next_sequence
    assert_equal seq + 1, uuid.next_sequence
    assert !UUID.state_file
  end

  def test_instance_generate
    uuid = UUID.new
    assert_match(/\A[\da-f]{32}\z/i, uuid.generate(:compact))

    assert_match(/\A[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 uuid.generate(:default))

    assert_match(/^urn:uuid:[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 uuid.generate(:urn))

    assert_match(/\A[\da-fA-f]{24}\z/i, uuid.generate(:teenie))

    e = assert_raise ArgumentError do
      uuid.generate :unknown
    end

    assert_equal 'invalid UUID format :unknown', e.message
  end

  def test_class_generate
    assert_match(/\A[\da-f]{32}\z/i, UUID.generate(:compact))

    assert_match(/\A[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 UUID.generate(:default))

    assert_match(/^urn:uuid:[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 UUID.generate(:urn))

    assert_match(/\A[\da-fA-f]{24}\z/i, UUID.generate(:teenie))

    e = assert_raise ArgumentError do
      UUID.generate :unknown
    end
    assert_equal 'invalid UUID format :unknown', e.message
  end

  def test_class_validate
    assert !UUID.validate('')

    assert  UUID.validate('01234567abcd8901efab234567890123'), 'compact'
    assert  UUID.validate('01234567-abcd-8901-efab-234567890123'), 'default'
    assert  UUID.validate('urn:uuid:01234567-abcd-8901-efab-234567890123'),
            'urn'
    assert  UUID.validate_teenie('4etJlQGyu04qEJs002f129iS'), 'teenie'

    assert  UUID.validate('01234567ABCD8901EFAB234567890123'), 'compact'
    assert  UUID.validate('01234567-ABCD-8901-EFAB-234567890123'), 'default'
    assert  UUID.validate('urn:uuid:01234567-ABCD-8901-EFAB-234567890123'),
            'urn'
    assert  UUID.validate_teenie('1ldIDgGyv04qEJs002f129iS'), 'teenie'
  end

  def test_class_invalids
    assert_nil  UUID.validate('01234567abcd8901efab234567890123000'), 'compact - too long'
    assert_nil  UUID.validate('01234567abcd8901efab23456789012'), 'compact - too short'
    assert_nil  UUID.validate('01234567abcd8901efzb234567890123'), 'compact - bad chars'

    assert_nil  UUID.validate_teenie('1ldIDgGyv04qEJs002f129iSaaaaa'), 'teenie - too long'
    assert_nil  UUID.validate_teenie('4etJlQGyu04qEJs02f129iS'), 'teenie - too short'
    assert_nil  UUID.validate_teenie('1ldIDgGyv04qEJs002f1-9iS'), 'teenie - bad chars'
  end

  def test_monotonic
    seen = {}
    uuid_gen = UUID.new

    20_000.times do
      uuid = uuid_gen.generate
      assert !seen.has_key?(uuid), "UUID repeated"
      seen[uuid] = true
    end
  end

  def test_same_mac
    class << foo = UUID.new
      attr_reader :mac
    end
    class << bar = UUID.new
      attr_reader :mac
    end
    assert_equal foo.mac, bar.mac
  end

  def test_increasing_sequence
    class << foo = UUID.new
      attr_reader :sequence
    end
    class << bar = UUID.new
      attr_reader :sequence
    end
    assert_equal foo.sequence + 1, bar.sequence
  end

end

