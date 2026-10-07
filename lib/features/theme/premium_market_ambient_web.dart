import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../models/theme_def.dart';
import '../music/music_zones.dart';
import 'premium_market_ambient.dart' show AmbientGlass;

/// Web ambient: ONE platform view (a DOM container) that holds
///   1. the theme's <video> (muted, autoplay, loop, playsinline), object-fit
///      contain in the export's 200vw x 200vh box;
///   2. an opaque WebGL canvas over it that draws SimpleBackgroundVideo.tsx's
///      `filter: blur(20px) brightness(0.5) contrast(1.2)` + `opacity` over the
///      App root's #000 -> #111 gradient. The canvas is a quarter of the box's
///      CSS size and the Gaussian runs at sigma 20 / 4 = 5 canvas px, so on
///      screen it is the same 20px blur, but it filters ~1/16 of the pixels
///      (and 1/144 at 3x DPR) of the CSS filter, once per decoded video frame;
///   3. the export's backdrop-blur elements (header `backdrop-blur-md`, search
///      input `backdrop-blur-sm`) as CSS backdrop-filter divs.
/// Before, the video and each backdrop element were separate platform views,
/// which split the Flutter scene into extra overlay canvases every frame.
/// Without WebGL it falls back to the CSS filter on the <video> (the original
/// rendering), still in the single container.
class AmbientMedia extends StatefulWidget {
  final WallpaperTheme theme;
  final bool owned;
  final Size viewport;
  final List<AmbientGlass> glass;

  const AmbientMedia({
    super.key,
    required this.theme,
    this.owned = false,
    this.viewport = Size.zero,
    this.glass = const [],
  });

  @override
  State<AmbientMedia> createState() => _AmbientMediaState();
}

/// Blur path: `css` (CSS filter on the <video>), `2d` (canvas 2D `filter` at
/// quarter resolution; falls back to css where unsupported, e.g. Safari) or
/// `gl` (WebGL at quarter resolution). `--dart-define=COLLIDER_AMBIENT_BLUR=...`
const String _kBlurMode = String.fromEnvironment('COLLIDER_AMBIENT_BLUR', defaultValue: 'css');

@JS('__colliderAmbient')
external JSFunction? get _ambientFactory;

class _AmbientMediaState extends State<AmbientMedia> {
  JSObject? _renderer;

  static String _url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return ui_web.assetManager.getAssetUrl(path);
  }

  static void _ensureScript() {
    if (_ambientFactory != null) return;
    final s = web.HTMLScriptElement()..text = _kAmbientJs;
    web.document.head!.append(s);
  }

  JSArray<JSObject> _glassJs() {
    final extra = MusicZones.widgetGlass.value;
    // The floating music widget over the market: its rect is global, so map
    // it into this 200% box through the box's own global origin.
    Offset origin = Offset(-widget.viewport.width / 2, -widget.viewport.height / 2);
    final ro = extra == null ? null : context.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) origin = ro.localToGlobal(Offset.zero);
    return <JSObject>[
      ..._fixedGlassJs(),
      if (extra != null)
        <String, Object>{
          'x': extra.rect.left - origin.dx,
          'y': extra.rect.top - origin.dy,
          'w': extra.rect.width,
          'h': extra.rect.height,
          'r': extra.radius,
          's': extra.sigma,
        }.jsify() as JSObject,
    ].toJS;
  }

  void _onWidgetGlass() => _renderer?.callMethod('setGlass'.toJS, _glassJs());

  @override
  void initState() {
    super.initState();
    MusicZones.widgetGlass.addListener(_onWidgetGlass);
  }

  List<JSObject> _fixedGlassJs() => <JSObject>[
        for (final g in widget.glass)
          <String, Object>{
            // box coordinates: the viewport sits at (w/2, h/2) in the 200% box
            'x': g.rect.left + widget.viewport.width / 2,
            'y': g.rect.top + widget.viewport.height / 2,
            'w': g.rect.width,
            'h': g.rect.height,
            'r': g.radius,
            's': g.sigma,
          }.jsify() as JSObject,
      ];

  @override
  void didUpdateWidget(covariant AmbientMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    final r = _renderer;
    if (r == null) return;
    if (oldWidget.owned != widget.owned) {
      r.callMethod('setOwned'.toJS, widget.owned.toJS);
    }
    if (!listEquals(oldWidget.glass, widget.glass) ||
        oldWidget.viewport != widget.viewport) {
      r.callMethod('setGlass'.toJS, _glassJs());
    }
  }

  @override
  void dispose() {
    MusicZones.widgetGlass.removeListener(_onWidgetGlass);
    _renderer?.callMethod('dispose'.toJS);
    _renderer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.theme.videoPath;
    final poster = widget.theme.assetPath;
    return HtmlElementView.fromTagName(
      tagName: 'div',
      isVisible: true,
      onElementCreated: (Object element) {
        _ensureScript();
        final opts = <String, Object>{
          'video': (video != null && video.isNotEmpty) ? _url(video) : '',
          'poster': _url(poster),
          'owned': widget.owned,
          'mode': _kBlurMode,
        }.jsify() as JSObject;
        opts['glass'] = _glassJs();
        _renderer = _ambientFactory!
            .callAsFunction(null, element as web.HTMLElement, opts) as JSObject?;
      },
    );
  }
}

bool listEquals(List<AmbientGlass> a, List<AmbientGlass> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The renderer. Plain JS so the WebGL calls stay 1:1 readable.
const String _kAmbientJs = r'''
(function () {
  if (window.__colliderAmbient) return;
  var SCALE = 4;            // canvas px = CSS px / 4
  var SIGMA = 20 / SCALE;   // blur(20px)
  var VS = 'attribute vec2 p;varying vec2 uv;void main(){uv=p*.5+.5;gl_Position=vec4(p,0.,1.);}';
  // Pass 1: box -> video (object-fit: contain, transparent outside), horizontal Gaussian.
  var FS1 = 'precision mediump float;varying vec2 uv;uniform sampler2D t;uniform vec4 vr;uniform vec2 px;uniform float sg;' +
    'vec4 S(vec2 b){vec2 q=(b-vr.xy)/vr.zw;vec2 k=step(vec2(0.),q)*step(q,vec2(1.));return texture2D(t,clamp(q,0.,1.))*(k.x*k.y);}' +
    'void main(){vec2 b=vec2(uv.x,1.-uv.y);vec4 a=vec4(0.);float ws=0.;' +
    'for(int i=-10;i<=10;i++){float x=float(i)*1.5;float w=exp(-x*x/(2.*sg*sg));a+=S(b+vec2(x*px.x,0.))*w;ws+=w;}' +
    'gl_FragColor=a/ws;}';
  // Pass 2: vertical Gaussian, then brightness -> contrast (CSS filter order), opacity over the #000 -> #111 root.
  var FS2 = 'precision mediump float;varying vec2 uv;uniform sampler2D t;uniform vec2 px;uniform float sg;uniform float br;uniform float op;' +
    'void main(){vec4 a=vec4(0.);float ws=0.;' +
    'for(int i=-10;i<=10;i++){float y=float(i)*1.5;float w=exp(-y*y/(2.*sg*sg));a+=texture2D(t,uv+vec2(0.,y*px.y))*w;ws+=w;}' +
    'a/=ws;vec3 c=a.a>0.0001?a.rgb/a.a:vec3(0.);c=clamp(c*br,0.,1.);c=clamp((c-.5)*1.2+.5,0.,1.);' +
    'float by=1.-uv.y;float g=clamp((by-.25)/.5,0.,1.)*(17./255.);' +
    'gl_FragColor=vec4(mix(vec3(g),c,a.a*op),1.);}';

  function ease(t) { return t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }

  window.__colliderAmbient = function (root, o) {
    var st = root.style;
    st.position = 'relative'; st.overflow = 'hidden'; st.pointerEvents = 'none';
    st.width = '100%'; st.height = '100%';
    var v = document.createElement('video');
    v.muted = true; v.defaultMuted = true; v.autoplay = true; v.loop = true; v.playsInline = true;
    v.setAttribute('muted', ''); v.setAttribute('playsinline', ''); v.setAttribute('autoplay', '');
    v.crossOrigin = 'anonymous';
    v.poster = o.poster;
    var vs = v.style;
    vs.position = 'absolute'; vs.left = '0'; vs.top = '0'; vs.width = '100%'; vs.height = '100%';
    vs.objectFit = 'contain'; vs.border = 'none'; vs.outline = 'none'; vs.pointerEvents = 'none';
    root.appendChild(v);

    var dead = false, owned = !!o.owned, loaded = false;
    var opNow = 0.3, brNow = owned ? 1 : 0.5, anim = null;
    function targetOp() { return loaded ? (owned ? 1 : 0.7) : 0.3; }
    function targetBr() { return owned ? 1 : 0.5; }

    // ---- WebGL path -------------------------------------------------------
    var cv = document.createElement('canvas');
    var cs = cv.style;
    cs.position = 'absolute'; cs.left = '0'; cs.top = '0'; cs.width = '100%'; cs.height = '100%';
    cs.pointerEvents = 'none';
    var gl = null, gl2 = false;
    try {
      if (o.mode !== 'gl') throw 'not-gl';
      var ca = { alpha: false, antialias: false, depth: false, stencil: false, premultipliedAlpha: false, preserveDrawingBuffer: false, powerPreference: 'low-power' };
      gl = cv.getContext('webgl2', ca); gl2 = !!gl;
      if (!gl) gl = cv.getContext('webgl', ca);
    } catch (e) { gl = null; }

    var P1, P2, buf, texV, texF, fbo, W = 0, H = 0, srcW = 0, srcH = 0, posterImg = null, haveSrc = false;
    function sh(type, src) { var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw gl.getShaderInfoLog(s); return s; }
    function prog(fs) { var p = gl.createProgram(); gl.attachShader(p, sh(gl.VERTEX_SHADER, VS)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, fs)); gl.bindAttribLocation(p, 0, 'p'); gl.linkProgram(p); if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw gl.getProgramInfoLog(p); return p; }
    function tex(mip) {
      var t = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, t);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, mip ? gl.LINEAR_MIPMAP_LINEAR : gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      return t;
    }
    function useCss() {
      // Original rendering: CSS filter on the <video>.
      gl = null; if (cv.parentNode) cv.parentNode.removeChild(cv);
      vs.setProperty('filter', 'blur(20px) brightness(' + targetBr() + ') contrast(1.2)');
      vs.opacity = String(targetOp());
      vs.setProperty('transition', 'opacity 1s ease-in-out');
    }
    var c2 = null;
    if (!gl && o.mode === '2d') {
      try { c2 = cv.getContext('2d', { alpha: false, desynchronized: false }); } catch (e) { c2 = null; }
      if (c2 && typeof c2.filter === 'string') { c2.filter = 'blur(1px)'; if (c2.filter !== 'blur(1px)') c2 = null; } else c2 = null;
      if (c2) { c2.filter = 'none'; root.appendChild(cv); }
    }
    function draw2d() {
      var r = root.getBoundingClientRect();
      var w = Math.max(2, Math.round(r.width / SCALE)), h = Math.max(2, Math.round(r.height / SCALE));
      if (w !== W || h !== H) { W = w; H = h; cv.width = w; cv.height = h; }
      // App root #000 -> #111 over the viewport (the box's middle half)
      var g = c2.createLinearGradient(0, H / 4, 0, H * 3 / 4);
      g.addColorStop(0, '#000000'); g.addColorStop(1, '#111111');
      c2.filter = 'none'; c2.globalAlpha = 1; c2.fillStyle = g; c2.fillRect(0, 0, W, H);
      var src = v.readyState >= 2 && v.videoWidth > 0 ? v : (posterImg && posterImg.complete && posterImg.naturalWidth ? posterImg : null);
      if (!src) return;
      var sw = src === v ? v.videoWidth : posterImg.naturalWidth, shh = src === v ? v.videoHeight : posterImg.naturalHeight;
      var s = Math.min(W / sw, H / shh), dw = sw * s, dh = shh * s;
      c2.filter = 'blur(' + SIGMA + 'px) brightness(' + brNow + ') contrast(1.2)';
      c2.globalAlpha = opNow;
      c2.drawImage(src, (W - dw) / 2, (H - dh) / 2, dw, dh);
    }
    if (c2) {
      // handled by draw2d
    } else if (gl) {
      try {
        P1 = prog(FS1); P2 = prog(FS2);
        buf = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, buf);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
        texV = tex(gl2); texF = tex(false); fbo = gl.createFramebuffer();
        root.appendChild(cv);
      } catch (e) { useCss(); }
    } else { useCss(); }
    var live = function () { return !!(gl || c2); };

    function resize() {
      var r = root.getBoundingClientRect();
      var w = Math.max(2, Math.round(r.width / SCALE)), h = Math.max(2, Math.round(r.height / SCALE));
      if (w === W && h === H) return false;
      W = w; H = h; cv.width = w; cv.height = h;
      gl.bindTexture(gl.TEXTURE_2D, texF);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texF, 0);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      return true;
    }
    function upload(src, w, h) {
      gl.bindTexture(gl.TEXTURE_2D, texV);
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, src);
      if (gl2) gl.generateMipmap(gl.TEXTURE_2D);
      srcW = w; srcH = h; haveSrc = true;
    }
    function draw() {
      if (dead) return;
      if (c2) { draw2d(); return; }
      if (!gl) return;
      resize();
      if (!haveSrc) return;
      // object-fit: contain inside the box (box uv, top-left origin)
      var bw = W * SCALE, bh = H * SCALE, s = Math.min(bw / srcW, bh / srcH);
      var rw = srcW * s / bw, rh = srcH * s / bh;
      gl.viewport(0, 0, W, H);
      gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.enableVertexAttribArray(0);
      gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
      gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
      gl.useProgram(P1);
      gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, texV);
      gl.uniform1i(gl.getUniformLocation(P1, 't'), 0);
      gl.uniform4f(gl.getUniformLocation(P1, 'vr'), (1 - rw) / 2, (1 - rh) / 2, rw, rh);
      gl.uniform2f(gl.getUniformLocation(P1, 'px'), 1 / W, 1 / H);
      gl.uniform1f(gl.getUniformLocation(P1, 'sg'), SIGMA);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.useProgram(P2);
      gl.bindTexture(gl.TEXTURE_2D, texF);
      gl.uniform1i(gl.getUniformLocation(P2, 't'), 0);
      gl.uniform2f(gl.getUniformLocation(P2, 'px'), 1 / W, 1 / H);
      gl.uniform1f(gl.getUniformLocation(P2, 'sg'), SIGMA);
      gl.uniform1f(gl.getUniformLocation(P2, 'br'), brNow);
      gl.uniform1f(gl.getUniformLocation(P2, 'op'), opNow);
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
    function frame() {
      if (dead) return;
      if (c2) { draw2d(); return; }
      if (!gl) return;
      if (v.readyState >= 2 && v.videoWidth > 0) {
        try { upload(v, v.videoWidth, v.videoHeight); } catch (e) { useCss(); return; }
      }
      draw();
    }
    // Opacity / brightness transitions (isLoading 0.3 -> 0.7 over 1s ease-in-out; owned lift).
    function animateTo(ms) {
      if (!live()) { useCss(); return; }
      var o0 = opNow, b0 = brNow, o1 = targetOp(), b1 = targetBr(), t0 = performance.now();
      if (anim) cancelAnimationFrame(anim);
      function step(now) {
        var k = Math.min(1, (now - t0) / ms), e = ease(k);
        opNow = o0 + (o1 - o0) * e; brNow = b0 + (b1 - b0) * e;
        draw();
        anim = k < 1 && !dead ? requestAnimationFrame(step) : null;
      }
      anim = requestAnimationFrame(step);
    }
    // One upload + draw per decoded video frame (not per display frame).
    var rvfc = typeof v.requestVideoFrameCallback === 'function';
    var rafId = null, lastT = -1;
    function onVideoFrame() { if (dead) return; frame(); v.requestVideoFrameCallback(onVideoFrame); }
    function poll() { if (dead) return; if (v.currentTime !== lastT) { lastT = v.currentTime; frame(); } rafId = requestAnimationFrame(poll); }
    if (live()) { if (rvfc) v.requestVideoFrameCallback(onVideoFrame); else rafId = requestAnimationFrame(poll); }

    v.addEventListener('loadeddata', function () { loaded = true; frame(); animateTo(1000); });
    v.addEventListener('seeked', function () { frame(); });
    if (live() && o.poster) {
      posterImg = new Image(); posterImg.crossOrigin = 'anonymous';
      posterImg.onload = function () { if (c2) { draw2d(); return; } if (!dead && gl && !(v.readyState >= 2)) { try { upload(posterImg, posterImg.naturalWidth, posterImg.naturalHeight); draw(); } catch (e) {} } };
      posterImg.src = o.poster;
    }
    if (o.video) { v.src = o.video; var pr = v.play(); if (pr && pr.catch) pr.catch(function () {}); }
    // Autoplay can be refused before the first gesture; retry on the first one.
    function kick() { if (v.paused && !dead) { var p2 = v.play(); if (p2 && p2.catch) p2.catch(function () {}); } }
    window.addEventListener('pointerdown', kick, { once: true, capture: true });
    v.addEventListener('canplay', kick);

    // ---- export backdrop-blur elements ----------------------------------
    var glassEls = [];
    function setGlass(list) {
      // Reuse the divs (the music widget's rect updates per drag frame).
      list = list || [];
      while (glassEls.length > list.length) glassEls.pop().remove();
      list.forEach(function (g, i) {
        var d = glassEls[i];
        if (!d) { d = document.createElement('div'); root.appendChild(d); glassEls.push(d); }
        var s = d.style;
        s.position = 'absolute'; s.left = g.x + 'px'; s.top = g.y + 'px'; s.width = g.w + 'px'; s.height = g.h + 'px';
        s.borderRadius = g.r + 'px'; s.overflow = 'hidden'; s.pointerEvents = 'none';
        s.setProperty('backdrop-filter', 'blur(' + g.s + 'px)');
        s.setProperty('-webkit-backdrop-filter', 'blur(' + g.s + 'px)');
      });
    }
    setGlass(o.glass);

    var ro = typeof ResizeObserver === 'function' ? new ResizeObserver(function () { if (live()) draw(); }) : null;
    if (ro) ro.observe(root);

    return {
      setOwned: function (b) {
        owned = !!b;
        if (live()) animateTo(600);
        else { vs.setProperty('filter', 'blur(20px) brightness(' + targetBr() + ') contrast(1.2)'); vs.opacity = String(targetOp()); }
      },
      setGlass: setGlass,
      refresh: frame,
      dispose: function () {
        dead = true; if (anim) cancelAnimationFrame(anim); if (rafId) cancelAnimationFrame(rafId);
        if (ro) ro.disconnect();
        window.removeEventListener('pointerdown', kick, { capture: true });
        try { v.pause(); v.removeAttribute('src'); v.load(); } catch (e) {}
        if (gl) { var lose = gl.getExtension('WEBGL_lose_context'); if (lose) lose.loseContext(); }
        gl = null; c2 = null;
      },
      debug: function () { return { mode: c2 ? '2d' : (gl ? 'gl' : 'css'), gl: !!gl, gl2: gl2, w: W, h: H, srcW: srcW, srcH: srcH, op: opNow, br: brNow, paused: v.paused, t: v.currentTime }; },
      video: v
    };
  };
})();
''';
