###
# test the translate method
#
require "test/unit"
require "uuid"

class TestTranslate < Test::Unit::TestCase

  def test_default_to_teenie_and_back

    11.times do
      uuid = UUID.new
      original_uuid = uuid.generate()

      teenie_uuid = UUID.translate(original_uuid, :default, :teenie)
      assert UUID.validate_teenie(teenie_uuid), 'teenie'

      default_uuid = UUID.translate(teenie_uuid, :teenie, :default)
      assert UUID.validate(default_uuid), 'default'

      assert default_uuid == original_uuid, 'got back what we started with'
    end
  end

  def test_teenie_to_compact_and_back

    7.times do
      uuid = UUID.new
      original_uuid = uuid.generate(:teenie)

      compact_uuid = UUID.translate(original_uuid, :teenie, :compact)
      assert UUID.validate(compact_uuid), 'compact'

      teenie_uuid = UUID.translate(compact_uuid, :compact, :teenie)
      assert UUID.validate_teenie(teenie_uuid), 'teenie'

      assert teenie_uuid == original_uuid, 'got back what we started with'
    end
  end
end