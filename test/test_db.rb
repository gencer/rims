# -*- coding: utf-8 -*-

require 'pp' if $DEBUG
require 'rims'
require 'set'
require 'test/unit'
require 'time'

module RIMS::Test
  class GlobalDBTest < Test::Unit::TestCase
    def setup
      @kv_store = {}
      @g_db = RIMS::GlobalDB.new(RIMS::GDBM_KeyValueStore.new(@kv_store))
    end

    def teardown
      pp @kv_store if $DEBUG
    end

    def test_cnum
      @g_db.setup
      assert_equal(0, @g_db.cnum)
      @g_db.cnum_succ!
      assert_equal(1, @g_db.cnum)
    end

    def test_uidvalidity
      @g_db.setup
      assert_equal(1, @g_db.uidvalidity)
    end

    def test_mbox
      @g_db.setup

      id = @g_db.add_mbox('INBOX')
      assert_kind_of(Integer, id)
      assert_equal('INBOX', @g_db.mbox_name(id))
      assert_equal(id, @g_db.mbox_id('INBOX'))
      assert_equal([ id ], @g_db.each_mbox_id.to_a)

      pp @kv_store if $DEBUG

      assert_equal('INBOX', @g_db.rename_mbox(id, 'foo'))
      assert_equal('foo', @g_db.mbox_name(id))
      assert_equal(id, @g_db.mbox_id('foo'))
      assert_nil(@g_db.mbox_id('INBOX'))
      assert_equal([ id ], @g_db.each_mbox_id.to_a)

      pp @kv_store if $DEBUG

      @g_db.del_mbox(id)
      assert_nil(@g_db.mbox_name(id))
      assert_nil(@g_db.mbox_id('foo'))
      assert_equal([], @g_db.each_mbox_id.to_a)

      id2 = @g_db.add_mbox('INBOX')
      assert_kind_of(Integer, id2)
      assert(id2 > id)
      assert_equal('INBOX', @g_db.mbox_name(id2))
      assert_equal(id2, @g_db.mbox_id('INBOX'))
      assert_equal([ id2 ], @g_db.each_mbox_id.to_a)
    end
  end

  class MessageDBTest < Test::Unit::TestCase
    def setup
      @text_st = {}
      @attr_st = {}
      @msg_db = RIMS::MessageDB.new(RIMS::GDBM_KeyValueStore.new(@text_st),
                                    RIMS::GDBM_KeyValueStore.new(@attr_st)).setup
    end

    def teardown
      pp @text_st, @attr_st if $DEBUG
    end

    def test_msg
      t0 = Time.now
      id = @msg_db.add_msg('foo')
      assert_kind_of(Integer, id)
      assert_equal('foo', @msg_db.msg_text(id))
      assert(@msg_db.msg_date(id) >= t0)
      assert_equal([ id ], @msg_db.each_msg_id.to_a)

      pp @text_st, @attr_st if $DEBUG

      assert_equal([].to_set, @msg_db.msg_mboxes(id))
      assert(@msg_db.add_msg_mbox(id, 0))   # changed.
      assert_equal([ 0 ].to_set, @msg_db.msg_mboxes(id))
      assert(! @msg_db.add_msg_mbox(id, 0)) # not changed.
      assert_equal([ 0 ].to_set, @msg_db.msg_mboxes(id))
      assert(@msg_db.add_msg_mbox(id, 1))   # changed.
      assert_equal([ 0, 1 ].to_set, @msg_db.msg_mboxes(id))
      assert(! @msg_db.add_msg_mbox(id, 1)) # not changed.
      assert_equal([ 0, 1 ].to_set, @msg_db.msg_mboxes(id))
      assert(@msg_db.del_msg_mbox(id, 0))   # changed.
      assert_equal([ 1 ].to_set, @msg_db.msg_mboxes(id))
      assert(! @msg_db.del_msg_mbox(id, 0)) # not changed.
      assert_equal([ 1 ].to_set, @msg_db.msg_mboxes(id))

      pp @text_st, @attr_st if $DEBUG

      assert_equal(false, @msg_db.msg_flag(id, 'seen'))
      assert_equal(0, @msg_db.mbox_flags(1, 'seen'))
      assert(@msg_db.set_msg_flag(id, 'seen', true)) # changed.
      assert_equal(true, @msg_db.msg_flag(id, 'seen'))
      assert_equal(1, @msg_db.mbox_flags(1, 'seen'))
      assert(! @msg_db.set_msg_flag(id, 'seen', true)) # not changed.
      assert_equal(true, @msg_db.msg_flag(id, 'seen'))
      assert_equal(1, @msg_db.mbox_flags(1, 'seen'))
      assert(@msg_db.set_msg_flag(id, 'seen', false)) # changed.
      assert_equal(false, @msg_db.msg_flag(id, 'seen'))
      assert_equal(0, @msg_db.mbox_flags(1, 'seen'))
      assert(! @msg_db.set_msg_flag(id, 'seen', false)) # not changed.
      assert_equal(false, @msg_db.msg_flag(id, 'seen'))
      assert_equal(0, @msg_db.mbox_flags(1, 'seen'))

      pp @text_st, @attr_st if $DEBUG

      id2 = @msg_db.add_msg('bar', Time.parse('1975-11-19 12:34:56'))
      assert_kind_of(Integer, id2)
      assert(id2 > id)
      assert_equal('bar', @msg_db.msg_text(id2))
      assert_equal(Time.parse('1975-11-19 12:34:56'), @msg_db.msg_date(id2))
      assert_equal([ id, id2 ], @msg_db.each_msg_id.to_a)

      pp @text_st, @attr_st if $DEBUG

      assert(@msg_db.del_msg_mbox(id, 1)) # changed.
      assert_equal([ id2 ], @msg_db.each_msg_id.to_a)
    end
  end

  class MailboxDBTest < Test::Unit::TestCase
    def setup
      @kv_store = {}
      @mbox_db = RIMS::MailboxDB.new(RIMS::GDBM_KeyValueStore.new(@kv_store)).setup
    end

    def teardown
      pp @kv_store if $DEBUG
    end

    def test_attributes
      @mbox_db.mbox_id = 0
      assert_equal(0, @mbox_db.mbox_id)

      @mbox_db.mbox_name = 'INBOX'
      assert_equal('INBOX', @mbox_db.mbox_name)
    end

    def test_msg
      assert_equal(0, @mbox_db.msgs)
      @mbox_db.add_msg(1)
      assert_equal(1, @mbox_db.msgs)
      assert_equal(0, @mbox_db.del_flags)
      assert_equal([ 1 ], @mbox_db.each_msg_id.to_a)

      assert_equal(false, @mbox_db.msg_flag_del(1))
      assert(@mbox_db.set_msg_flag_del(1, true)) # changed.
      assert_equal(true, @mbox_db.msg_flag_del(1))
      assert_equal(1, @mbox_db.del_flags)
      assert(! @mbox_db.set_msg_flag_del(1, true)) # not changed.
      assert_equal(true, @mbox_db.msg_flag_del(1))
      assert_equal(1, @mbox_db.del_flags)

      @mbox_db.expunge_msg(1)
      assert_equal(0, @mbox_db.msgs)
      assert_equal(0, @mbox_db.del_flags)
      assert_equal([], @mbox_db.each_msg_id.to_a)
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
