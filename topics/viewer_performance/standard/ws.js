// WebSocket counter, contract "blackbox-v4". Installed with Page.addScriptToEvaluateOnNewDocument, so it
// wraps the socket Shiny opens. It counts the bytes of every message in and out and keeps the largest
// single message; measure_session.R resets it at each click and reads it once the server and Chrome are
// quiet again, so messages that arrive after the page already looks finished are counted too.
// Text messages count in characters (one byte each for Shiny's ASCII JSON); binary ones in bytes.
// Not CDP's Network domain: its frame events carry the whole payload, and a message larger than
// chromote's websocket limit (a 29 MB cell-name message) breaks the CDP connection.
(function () {
  var W = window.WebSocket;
  if (!W || window.__cbws) return;
  var c = window.__cbws = {
    inBytes: 0, outBytes: 0, maxBytes: 0, inMsgs: 0, outMsgs: 0,
    reset: function () { c.inBytes = c.outBytes = c.maxBytes = c.inMsgs = c.outMsgs = 0; return true; },
    read: function () {
      return JSON.stringify({ ws_in_bytes: c.inBytes, ws_out_bytes: c.outBytes, ws_max_msg_bytes: c.maxBytes,
                              ws_in_msgs: c.inMsgs, ws_out_msgs: c.outMsgs });
    }
  };
  function size(d) {
    if (typeof d === 'string') return d.length;
    if (d instanceof ArrayBuffer) return d.byteLength;
    if (ArrayBuffer.isView(d)) return d.byteLength;
    if (typeof Blob !== 'undefined' && d instanceof Blob) return d.size;
    return 0;
  }
  var send = W.prototype.send;
  W.prototype.send = function (d) {
    var n = size(d);
    c.outBytes += n; c.outMsgs++; if (n > c.maxBytes) c.maxBytes = n;
    return send.apply(this, arguments);
  };
  function Counted(url, protocols) {
    var ws = protocols === undefined ? new W(url) : new W(url, protocols);
    ws.addEventListener('message', function (e) {
      var n = size(e.data);
      c.inBytes += n; c.inMsgs++; if (n > c.maxBytes) c.maxBytes = n;
    });
    return ws;
  }
  Counted.prototype = W.prototype;
  ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED'].forEach(function (k) { Counted[k] = W[k]; });
  window.WebSocket = Counted;
})();
