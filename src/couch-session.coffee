Store = require('connect').session.Store
cradle = require('cradle')
sys = require('sys')
db = null

session_maxAge = 3*60 # seconds

_check_error = (err) ->
  if err
    console.error("CouchSession")
    console.error(err)
    console.error( new Error().stack )

_uri_encode = (id) ->
  # We first decode it to escape any current URI encoding.
  encodeURIComponent(decodeURIComponent(id))

class CouchSession extends Store
  constructor: (opts) ->
    opts or= {}
    @setup(opts.database, opts)

  setup: (database, opts) =>
    opts or= {}
    if !database
      throw new Error("You must define a database")

    # We never ever want caching.
    opts.cache = false

    db = new(cradle.Connection)(opts).database(database)
    db.exists (err, exists) =>
      _check_error(err)
      if !exists
        db.create (err, res) =>
          _check_error(err)

  get: (sid, fn) =>
    sid = _uri_encode(sid)
    db.get sid, (err, sess) =>
      if sess
        if sess.lastAccess < Date.parse(sess.cookie.expires)
          fn(null, sess)
        else
          @destroy(sid)
          fn(null, null)
      else
        fn(null, null)

  set: (sid, sess, fn) =>
    sid = _uri_encode(sid)
    fn or= =>
    db.get sid, (err, doc) =>
      sess.touch()
      if !doc
        db.save(sid, sess, (err, got) ->
            fn err, got )
      else
        # Update the session object.
        db.save(sid, doc._rev, sess, fn)

  destroy: (sid, fn) =>
    sid = _uri_encode(sid)
    db.get sid, (err, doc) =>
      db.remove(sid, doc._rev, fn)

  # TODO length and clear ... it can be done with db.all

module.exports = CouchSession

