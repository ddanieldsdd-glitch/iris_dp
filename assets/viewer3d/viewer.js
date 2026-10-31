// Visor 3D de IRIS: dibuja la escena resuelta (formato iris.scene3d v1)
// que le manda la app. No guarda nada: Dart manda la escena y aquí solo se
// dibuja y se avisa de lo que se toca.
//
// Dart → JS: iris.load(escena), iris.view('top'|'front'|'right'|'iso'),
//            iris.set({cones, roof, ortho, bg, names}), iris.select(id).
// JS → Dart: flutter_inappwebview.callHandler('iris', {type, …}).
'use strict';

(function () {
  const msg = document.getElementById('msg');
  if (typeof THREE === 'undefined' || !THREE.OrbitControls) {
    msg.textContent = 'No se ha podido cargar three.js.';
    return;
  }

  // Ejes de la escena: x, y en planta y z arriba. three.js usa y arriba:
  // (x, y, z) → (x, z, −y) conserva la mano derecha.
  const V = (x, y, z) => new THREE.Vector3(x, z, -y);
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;

  function post(message) {
    const bridge = window.flutter_inappwebview;
    if (bridge && bridge.callHandler) bridge.callHandler('iris', message);
  }

  // ── Escena, cámaras y controles ──────────────────────────────────────────
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputEncoding = THREE.sRGBEncoding;
  renderer.autoClear = false;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  document.body.prepend(renderer.domElement);

  const scene = new THREE.Scene();
  let baseBg = '#1a2229';
  scene.background = new THREE.Color(baseBg);
  const camP = new THREE.PerspectiveCamera(45, 1, 0.05, 2000);
  const camO = new THREE.OrthographicCamera(-10, 10, 10, -10, -1000, 2000);
  let cam = camP;
  const controls = new THREE.OrbitControls(cam, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.12;
  controls.screenSpacePanning = true;
  controls.maxPolarAngle = Math.PI * 0.495;

  let root = new THREE.Group();
  scene.add(root);
  let cones = [];
  let roofs = [];
  let picks = [];
  let center = new THREE.Vector3();
  let radius = 20;
  let anim = null;
  let showCones = true;
  let showRoof = true;
  // Capas que se pueden ocultar desde la app.
  const LAYERS = ['walls', 'glass', 'drapes', 'pillars', 'rig', 'fixtures', 'people', 'props'];
  const shown = { walls: true, glass: true, drapes: true, pillars: true, rig: true, fixtures: true, people: true, props: true };
  // Colores por categoría (los manda la app, los mismos que en la planta) y
  // etiquetas con el nombre de cada pieza.
  let palette = {};
  let showNames = false;
  // Miniaturas 3/4 de los assets de Unreal (F6.20 B4): clave → textura.
  const thumbTex = {};
  const labelsGroup = new THREE.Group();
  let labels = [];
  scene.add(labelsGroup);
  let L = {};
  let lastScene = null;
  // Escaneos: se cargan una vez por archivo y se recolocan en cada escena.
  const scansGroup = new THREE.Group();
  scene.add(scansGroup);
  const scanCache = {};
  const scanWrappers = {};
  let floorLight = null;
  let measuring = false;
  let measurePts = [];
  let measureGroup = null;

  // Marco de la cámara: lo que entra en el plano.
  const frame = document.createElement('div');
  frame.style.cssText = 'position:absolute;border:2px solid rgba(232,150,63,.9);box-shadow:0 0 0 9999px rgba(0,0,0,.45);pointer-events:none;display:none';
  const frameLabel = document.createElement('div');
  frameLabel.style.cssText = 'position:absolute;left:6px;top:4px;color:#e8963f;font:600 12px -apple-system,system-ui,sans-serif';
  frame.appendChild(frameLabel);
  document.body.appendChild(frame);
  let camView = null;
  let selectedBox = null;

  // Cubo de vistas, arriba a la derecha.
  const CUBE = 84, M = 10;
  const cubeScene = new THREE.Scene();
  const cubeCam = new THREE.PerspectiveCamera(35, 1, 0.1, 20);
  const faceNames = ['DER', 'IZQ', 'ARRIBA', 'ABAJO', 'FRENTE', 'FONDO'];
  const cubeMesh = new THREE.Mesh(
    new THREE.BoxGeometry(1, 1, 1),
    faceNames.map((t) => {
      const c = document.createElement('canvas');
      c.width = c.height = 128;
      const g = c.getContext('2d');
      g.fillStyle = '#e7ebee';
      g.fillRect(0, 0, 128, 128);
      g.strokeStyle = '#7b8792';
      g.lineWidth = 6;
      g.strokeRect(3, 3, 122, 122);
      g.fillStyle = '#1e2933';
      g.font = '600 ' + (t.length > 5 ? 22 : 26) + 'px -apple-system, Helvetica, Arial';
      g.textAlign = 'center';
      g.textBaseline = 'middle';
      g.fillText(t, 64, 66);
      const tx = new THREE.CanvasTexture(c);
      tx.encoding = THREE.sRGBEncoding;
      return new THREE.MeshBasicMaterial({ map: tx });
    }),
  );
  cubeScene.add(cubeMesh);
  cubeScene.add(new THREE.LineSegments(
    new THREE.EdgesGeometry(cubeMesh.geometry),
    new THREE.LineBasicMaterial({ color: 0x55616b }),
  ));

  function size() { return { w: window.innerWidth, h: window.innerHeight }; }

  function resize() {
    const { w, h } = size();
    renderer.setSize(w, h, false);
    camP.aspect = w / Math.max(h, 1);
    camP.updateProjectionMatrix();
    orthoFrustum();
  }

  function orthoFrustum() {
    const { w, h } = size();
    const s = radius * 0.62;
    camO.left = -s * w / Math.max(h, 1);
    camO.right = s * w / Math.max(h, 1);
    camO.top = s;
    camO.bottom = -s;
    camO.updateProjectionMatrix();
  }

  window.addEventListener('resize', () => { resize(); placeFrame(); });

  // ── Toques ───────────────────────────────────────────────────────────────
  // El cubo cambia la vista. Un toque sin arrastrar selecciona. Arrastrar lo
  // seleccionado (foco, pilar, motor, persona, cámara) lo mueve por el
  // suelo; arrastrar el asa naranja de un foco cambia adónde apunta. Al
  // soltar se avisa a la app, que guarda y vuelve a mandar la escena.
  let down = null;
  let drag = null;
  let selectedId = null;
  let aimHandle = null;
  const ray = new THREE.Raycaster();

  function rayAt(e) {
    const { w, h } = size();
    ray.setFromCamera(new THREE.Vector2((e.clientX / w) * 2 - 1, -(e.clientY / h) * 2 + 1), cam);
    return ray;
  }

  function onPlane(e, y) {
    const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -y);
    const p = new THREE.Vector3();
    return rayAt(e).ray.intersectPlane(plane, p) ? p : null;
  }

  renderer.domElement.addEventListener('pointerdown', (e) => {
    const { w } = size();
    const x = e.clientX, y = e.clientY;
    const cx = w - M - CUBE, cy = M;
    if (x >= cx && x <= cx + CUBE && y >= cy && y <= cy + CUBE) {
      e.stopImmediatePropagation();
      const r = new THREE.Raycaster();
      r.setFromCamera(new THREE.Vector2(((x - cx) / CUBE) * 2 - 1, -((y - cy) / CUBE) * 2 + 1), cubeCam);
      const hit = r.intersectObject(cubeMesh)[0];
      if (hit) setView(['right', 'left', 'top', 'top', 'front', 'back'][hit.face.materialIndex]);
      return;
    }
    down = { x, y };
    // ¿Empieza un arrastre? El asa de puntería, o lo ya seleccionado.
    if (aimHandle && rayAt(e).intersectObject(aimHandle).length) {
      const at = onPlane(e, aimHandle.position.y);
      if (at) drag = { mode: 'aim', target: aimHandle, plane: aimHandle.position.y, last: at };
    } else if (selectedId) {
      const hit = rayAt(e).intersectObjects(picks, true).find((i) => idOf(i.object) === selectedId && visible(i.object));
      const target = hit && picks.find((o) => o.userData.id === selectedId);
      if (target && target.userData.movable) {
        const y0 = target.userData.dragY !== undefined ? target.userData.dragY : 0;
        const at = onPlane(e, y0);
        if (at) drag = { mode: 'move', target, plane: y0, start: at.clone(), last: at };
      }
    }
    if (drag) {
      e.stopImmediatePropagation();
      controls.enabled = false;
      renderer.domElement.setPointerCapture(e.pointerId);
    }
  }, true);

  renderer.domElement.addEventListener('pointermove', (e) => {
    if (!drag) return;
    const at = onPlane(e, drag.plane);
    if (!at) return;
    const d = at.clone().sub(drag.last);
    drag.last = at;
    drag.target.position.add(new THREE.Vector3(d.x, 0, d.z));
    if (drag.mode === 'aim' && aimHandle.userData.line) {
      const pos = aimHandle.userData.line.geometry.attributes.position;
      pos.setXYZ(1, aimHandle.position.x, aimHandle.position.y, aimHandle.position.z);
      pos.needsUpdate = true;
    }
    if (selectedBox) selectedBox.update();
  });

  renderer.domElement.addEventListener('pointerup', (e) => {
    if (drag) {
      const d = drag;
      drag = null;
      down = null;
      controls.enabled = true;
      if (d.mode === 'move') {
        const dx = d.last.x - d.start.x, dz = d.last.z - d.start.z;
        if (Math.hypot(dx, dz) > 0.01) post({ type: 'move', id: selectedId, dx, dy: -dz });
      } else {
        const p = aimHandle.position;
        post({ type: 'aim', id: selectedId, x: p.x, y: -p.z, z: p.y });
      }
      return;
    }
    if (!down) return;
    const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
    down = null;
    if (moved > 5) return;
    if (measuring) {
      measureAt(e);
      return;
    }
    // Lo pequeño que se mueve (un foco bajo su truss) gana a lo que tapa.
    const hits = rayAt(e).intersectObjects(picks, true).filter((i) => idOf(i.object) && visible(i.object));
    const hit = hits.find((i) => movableOf(i.object)) || hits[0];
    const id = hit ? idOf(hit.object) : null;
    highlight(id);
    post({ type: 'select', id });
  });

  function visible(o) {
    for (let p = o; p; p = p.parent) if (!p.visible) return false;
    return true;
  }

  function movableOf(o) {
    for (let p = o; p; p = p.parent) if (p.userData && p.userData.id) return !!p.userData.movable;
    return false;
  }

  function idOf(o) {
    for (let p = o; p; p = p.parent) if (p.userData && p.userData.id) return p.userData.id;
    return null;
  }

  function highlight(id) {
    selectedId = id;
    updateLabels();
    if (selectedBox) {
      scene.remove(selectedBox);
      selectedBox.geometry.dispose();
      selectedBox = null;
    }
    if (aimHandle) {
      scene.remove(aimHandle);
      if (aimHandle.userData.line) {
        scene.remove(aimHandle.userData.line);
        aimHandle.userData.line.geometry.dispose();
      }
      aimHandle.geometry.dispose();
      aimHandle = null;
    }
    if (!id) return;
    const target = picks.find((o) => o.userData.id === id);
    if (!target) return;
    selectedBox = new THREE.BoxHelper(target, 0xe8963f);
    scene.add(selectedBox);
    // Un foco lleva el asa de adónde apunta.
    if (target.userData.aim) {
      aimHandle = new THREE.Mesh(new THREE.SphereGeometry(0.18, 18, 12), new THREE.MeshBasicMaterial({ color: 0xe8963f }));
      aimHandle.position.copy(target.userData.aim);
      const line = new THREE.Line(
        new THREE.BufferGeometry().setFromPoints([target.position.clone(), target.userData.aim.clone()]),
        new THREE.LineDashedMaterial({ color: 0xe8963f, dashSize: 0.15, gapSize: 0.1 }),
      );
      line.computeLineDistances();
      aimHandle.userData.line = line;
      scene.add(aimHandle, line);
    }
  }

  // ── Construcción ─────────────────────────────────────────────────────────
  function dispose(o) {
    o.traverse((c) => {
      if (c.geometry) c.geometry.dispose();
      if (c.material) {
        (Array.isArray(c.material) ? c.material : [c.material]).forEach((m) => {
          if (m.map) m.map.dispose();
          m.dispose();
        });
      }
    });
  }

  function cyl(p, q, r, mat) {
    const d = new THREE.Vector3().subVectors(q, p);
    const L = d.length();
    const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, L, 6, 1, true), mat);
    m.position.copy(p).addScaledVector(d, 0.5);
    m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.normalize());
    return m;
  }

  function cctColor(k) {
    const t = clamp(k, 1000, 40000) / 100;
    let r, g, b;
    if (t <= 66) {
      r = 255;
      g = 99.47 * Math.log(t) - 161.12;
      b = t <= 19 ? 0 : 138.52 * Math.log(t - 10) - 305.04;
    } else {
      r = 329.7 * Math.pow(t - 60, -0.1332);
      g = 288.12 * Math.pow(t - 60, -0.0755);
      b = 255;
    }
    return new THREE.Color(clamp(r, 0, 255) / 255, clamp(g, 0, 255) / 255, clamp(b, 0, 255) / 255);
  }

  function quad(pos, a, b, c, d) { pos.push(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z); }

  function meshFrom(pos, mat, id) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.computeVertexNormals();
    const m = new THREE.Mesh(g, mat);
    if (id) m.name = id;
    if (id) { m.userData.id = id; picks.push(m); }
    return m;
  }

  function insidePoly(x, y, poly) {
    let inside = false;
    for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      const a = poly[i], b = poly[j];
      if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
    }
    return inside;
  }

  const stripes = (() => {
    const c = document.createElement('canvas');
    c.width = 64; c.height = 4;
    const x = c.getContext('2d');
    x.fillStyle = '#f3efe8'; x.fillRect(0, 0, 64, 4);
    x.fillStyle = '#c3333a'; x.fillRect(0, 0, 32, 4);
    return c;
  })();

  function addHall(h) {
    const g = h.roofGrid, z0 = h.z0 || 0;
    const pos = [], uv = [];
    const P = (i, j) => [g.origin[0] + g.stepX * i, g.origin[1] + g.stepY * j, z0 + g.z[j * (g.nx + 1) + i]];
    for (let j = 0; j < g.ny; j++) {
      for (let i = 0; i < g.nx; i++) {
        const a = P(i, j), b = P(i + 1, j), c = P(i + 1, j + 1), d = P(i, j + 1);
        const cx = (a[0] + c[0]) / 2, cy = (a[1] + c[1]) / 2;
        if (!insidePoly(cx, cy, h.outline)) continue;
        for (const p of [a, b, c, a, c, d]) {
          const v = V(p[0], p[1], p[2]);
          pos.push(v.x, v.y, v.z);
          uv.push(p[0], p[1] / 10);
        }
      }
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    geo.computeVertexNormals();
    let mat;
    if (h.roof === 'tensile') {
      const tx = new THREE.CanvasTexture(stripes);
      tx.wrapS = tx.wrapT = THREE.RepeatWrapping;
      tx.encoding = THREE.sRGBEncoding;
      mat = new THREE.MeshStandardMaterial({ map: tx, roughness: 0.8, side: THREE.DoubleSide, transparent: true, opacity: 0.9 });
    } else {
      mat = new THREE.MeshStandardMaterial({ color: 0x9aa3ab, metalness: 0.3, roughness: 0.6, side: THREE.DoubleSide, transparent: true, opacity: 0.6, depthWrite: false });
    }
    const roof = new THREE.Mesh(geo, mat);
    roof.visible = showRoof;
    roofs.push(roof);
    root.add(roof);
    // Suelo de la nave, a su cota.
    const shape = new THREE.Shape(h.outline.map((p) => new THREE.Vector2(p[0], p[1])));
    const floor = new THREE.Mesh(new THREE.ShapeGeometry(shape), new THREE.MeshStandardMaterial({ color: 0xb9a98e, roughness: 0.9 }));
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = z0 + 0.005;
    root.add(floor);
  }

  const wallMat = new THREE.MeshStandardMaterial({ color: 0xc3c9ce, roughness: 0.85, side: THREE.DoubleSide, transparent: true, opacity: 0.6, depthWrite: false });
  const glassMat = new THREE.MeshStandardMaterial({ color: 0x9fc7d6, roughness: 0.1, metalness: 0.1, side: THREE.DoubleSide, transparent: true, opacity: 0.25, depthWrite: false });

  function addWall(w) {
    const pts = w.points, z0 = w.z0 || 0, holes = w.openings || [];
    const cum = [0];
    for (let k = 1; k < pts.length; k++) cum.push(cum[k - 1] + Math.hypot(pts[k][0] - pts[k - 1][0], pts[k][1] - pts[k - 1][1]));
    const pos = [], glass = [];
    for (let k = 1; k < pts.length; k++) {
      const s0 = cum[k - 1], s1 = cum[k];
      if (s1 - s0 < 1e-6) continue;
      const cuts = [s0, s1];
      for (const o of holes) for (const s of [o.from, o.to]) if (s > s0 && s < s1) cuts.push(s);
      cuts.sort((a, b) => a - b);
      const at = (s) => { const t = (s - s0) / (s1 - s0); return [lerp(pts[k - 1][0], pts[k][0], t), lerp(pts[k - 1][1], pts[k][1], t), lerp(w.tops[k - 1], w.tops[k], t)]; };
      for (let c = 1; c < cuts.length; c++) {
        const a = at(cuts[c - 1]), b = at(cuts[c]);
        if (cuts[c] - cuts[c - 1] < 1e-6) continue;
        const mid = (cuts[c - 1] + cuts[c]) / 2;
        const hole = holes.find((o) => mid > o.from && mid < o.to);
        const face = (zLoA, zLoB, zHiA, zHiB, out) => {
          if (zHiA - zLoA < 1e-3 && zHiB - zLoB < 1e-3) return;
          quad(out, V(a[0], a[1], z0 + zLoA), V(b[0], b[1], z0 + zLoB), V(b[0], b[1], z0 + zHiB), V(a[0], a[1], z0 + zHiA));
        };
        if (!hole) {
          face(0, 0, a[2], b[2], pos);
        } else {
          face(0, 0, hole.sill, hole.sill, pos);
          face(Math.min(hole.head, a[2]), Math.min(hole.head, b[2]), a[2], b[2], pos);
          if (hole.glass) face(hole.sill, hole.sill, Math.min(hole.head, a[2]), Math.min(hole.head, b[2]), glass);
        }
      }
    }
    L.walls.add(meshFrom(pos, wallMat, w.id));
    if (glass.length) L.glass.add(meshFrom(glass, glassMat, null));
  }

  function addDrape(d) {
    const s = d.samples, z0 = d.z0 || 0;
    if (!s || s.length < 2) return;
    const nv = 12, pos = [];
    const pleat = 0.32 - 0.12 * Math.min(d.fullness || 0, 1);
    const amp = 0.025 + 0.06 * Math.min(d.fullness || 0, 1);
    const cum = [0];
    for (let k = 1; k < s.length; k++) cum.push(cum[k - 1] + Math.hypot(s[k].p[0] - s[k - 1].p[0], s[k].p[1] - s[k - 1].p[1]));
    const sub = 6;
    const rows = [];
    for (let k = 0; k < s.length - 1; k++) {
      for (let q = 0; q < sub; q++) rows.push([k, q / sub]);
    }
    rows.push([s.length - 2, 1]);
    const col = rows.map(([k, f]) => {
      const a = s[k], b = s[k + 1];
      const dx = b.p[0] - a.p[0], dy = b.p[1] - a.p[1], len = Math.hypot(dx, dy) || 1;
      return { x: lerp(a.p[0], b.p[0], f), y: lerp(a.p[1], b.p[1], f), top: lerp(a.top, b.top, f), bottom: lerp(a.bottom, b.bottom, f), nx: -dy / len, ny: dx / len, s: lerp(cum[k], cum[k + 1], f) };
    });
    const vert = (c, v, end) => {
      const z = lerp(c.bottom, c.top, v);
      const o = amp * Math.sin(2 * Math.PI * c.s / pleat) * (0.55 + 0.45 * (1 - v)) * (end ? 0.3 : 1);
      return V(c.x + c.nx * o, c.y + c.ny * o, z0 + z);
    };
    for (let i = 0; i < col.length - 1; i++) {
      for (let j = 0; j < nv; j++) {
        const e0 = i === 0, e1 = i + 1 === col.length - 1;
        quad(pos, vert(col[i], j / nv, e0), vert(col[i + 1], j / nv, e1), vert(col[i + 1], (j + 1) / nv, e1), vert(col[i], (j + 1) / nv, e0));
      }
    }
    const clear = (d.transmission || 0) > 0.3;
    const mat = new THREE.MeshStandardMaterial({ color: new THREE.Color(d.color || '#26262c'), roughness: d.material === 'pvc' ? 0.15 : 0.92, side: THREE.DoubleSide, transparent: clear, opacity: clear ? 0.4 : 1 });
    L.drapes.add(meshFrom(pos, mat, d.id));
    const rope = s.map((q) => V(q.p[0], q.p[1], z0 + q.top + 0.01));
    L.drapes.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(rope), new THREE.LineBasicMaterial({ color: 0x222222 })));
  }

  const steel = new THREE.MeshStandardMaterial({ color: 0xc8ccd0, metalness: 0.7, roughness: 0.35 });
  const lattice = new THREE.LineBasicMaterial({ color: 0x9aa2a9 });
  const dark = new THREE.MeshStandardMaterial({ color: 0x2a2d31, roughness: 0.6 });

  // Un truss de A a B (en planta) a la altura z0, o vertical (torre) desde A.
  function trussOf(A, B, z0, profile, s, vertical, id) {
    const offs = profile === 'triangle'
      ? [[-s / 2, 0], [s / 2, 0], [0, s * 0.87]]
      : profile === 'ladder' ? [[-s / 2, 0], [s / 2, 0]] : [[-s / 2, 0], [s / 2, 0], [-s / 2, s], [s / 2, s]];
    const faces = profile === 'triangle' ? [[0, 1], [0, 2], [1, 2]] : profile === 'ladder' ? [[0, 1]] : [[0, 1], [2, 3], [0, 2], [1, 3]];
    let P, L;
    if (vertical) {
      L = z0;
      P = (k, u) => V(A[0] + offs[k][0], A[1] + offs[k][1] - s / 2, u);
    } else {
      L = Math.hypot(B[0] - A[0], B[1] - A[1]);
      const ux = (B[0] - A[0]) / L, uy = (B[1] - A[1]) / L, nx = -uy, ny = ux;
      P = (k, u) => V(A[0] + ux * u + nx * offs[k][0], A[1] + uy * u + ny * offs[k][0], z0 + offs[k][1]);
    }
    const g = new THREE.Group();
    if (id) { g.userData.id = id; g.name = id; picks.push(g); }
    if (L < 0.05) return g;
    for (let k = 0; k < offs.length; k++) g.add(cyl(P(k, 0), P(k, L), 0.024, steel));
    const n = Math.max(1, Math.round(L / s)), pts = [];
    for (const [i, j] of faces) {
      for (let q = 0; q < n; q++) pts.push(P(q % 2 ? i : j, L * q / n), P(q % 2 ? j : i, L * (q + 1) / n));
      pts.push(P(i, 0), P(j, 0), P(i, L), P(j, L));
    }
    g.add(new THREE.LineSegments(new THREE.BufferGeometry().setFromPoints(pts), lattice));
    return g;
  }

  // ── Atrezzo ──────────────────────────────────────────────────────────
  // Formas sencillas por tipo, a sus medidas: lo justo para reconocerlo y
  // encuadrar. El modelo real (Fab, Megascans) solo vive en Unreal. Se
  // construyen mirando a −Z (el frente) con la base en el suelo.
  function catColor(cat) {
    return new THREE.Color(palette[cat] || '#9aa0a6');
  }

  function box(w, h, d, mat, x, y, z) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(Math.max(w, 0.01), Math.max(h, 0.01), Math.max(d, 0.01)), mat);
    m.position.set(x || 0, y === undefined ? h / 2 : y, z || 0);
    return m;
  }

  function propShape(p, mat) {
    const g = new THREE.Group();
    const s = Math.max(p.sizeM || 0.5, 0.1), h = Math.max(p.heightM || 0.8, 0.05);
    // Ancho (de lado) y fondo (hacia donde mira), F6.21.3.
    const w = Math.max(p.widthM || s, 0.1), d = Math.max(p.depthM || s, 0.1);
    const leg = (x, z, top) => {
      const m = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, top, 8), mat);
      m.position.set(x, top / 2, z);
      return m;
    };
    switch (p.type) {
      case 'table': {
        const t = Math.min(0.05, h * 0.1), ex = w / 2 - 0.06, ez = d / 2 - 0.06;
        g.add(box(w, t, d, mat, 0, h - t / 2));
        for (const [x, z] of [[-ex, -ez], [ex, -ez], [-ex, ez], [ex, ez]]) g.add(leg(x, z, h - t));
        break;
      }
      case 'chair': {
        const seat = Math.min(0.46, h * 0.58), ex = w / 2 - 0.04, ez = d / 2 - 0.04;
        g.add(box(w, 0.05, d, mat, 0, seat));
        g.add(box(w, h - seat, 0.05, mat, 0, seat + (h - seat) / 2, d / 2 - 0.025));
        for (const [x, z] of [[-ex, -ez], [ex, -ez], [-ex, ez], [ex, ez]]) g.add(leg(x, z, seat));
        break;
      }
      case 'sofa': {
        const seat = Math.min(0.45, h * 0.55);
        g.add(box(w, seat, d, mat));
        g.add(box(w, h - seat, 0.18, mat, 0, seat + (h - seat) / 2, d / 2 - 0.09));
        g.add(box(0.16, seat + 0.18, d, mat, -w / 2 + 0.08, (seat + 0.18) / 2));
        g.add(box(0.16, seat + 0.18, d, mat, w / 2 - 0.08, (seat + 0.18) / 2));
        break;
      }
      case 'bed': {
        const top = Math.min(0.55, h);
        g.add(box(w, top, d, mat));
        g.add(box(w, Math.max(h, top + 0.4) - top, 0.08, mat, 0, top + (Math.max(h, top + 0.4) - top) / 2, d / 2 - 0.04));
        break;
      }
      case 'vehicle': {
        const w = Math.max(s * 0.42, 0.6), body = h * 0.55;
        g.add(box(w, body, s, mat, 0, body / 2 + 0.15));
        g.add(box(w * 0.92, h - body - 0.15, s * 0.5, mat, 0, body + 0.15 + (h - body - 0.15) / 2, s * 0.05));
        break;
      }
      case 'tree': {
        const crown = Math.min(s / 2, h * 0.45);
        const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.06 + s * 0.03, 0.09 + s * 0.04, h - crown, 10), new THREE.MeshStandardMaterial({ color: 0x6b5340, roughness: 0.9 }));
        trunk.position.y = (h - crown) / 2;
        const top = new THREE.Mesh(new THREE.SphereGeometry(crown, 16, 12), mat);
        top.position.y = h - crown;
        g.add(trunk, top);
        break;
      }
      case 'rock': {
        const r = new THREE.Mesh(new THREE.DodecahedronGeometry(s / 2, 0), mat);
        r.scale.y = h / s;
        r.position.y = h / 2;
        g.add(r);
        break;
      }
      default:
        g.add(box(w, h, d, mat));
    }
    return g;
  }

  // ── Etiquetas ────────────────────────────────────────────────────────
  // Un cartel con el nombre, siempre de cara a la cámara y por encima de
  // lo demás. Con «Nombres» se ven todos; si no, solo el del seleccionado.
  // Alto de una etiqueta en pantalla, en píxeles: igual de cerca que de
  // lejos, también en una nave de 40 m vista entera.
  const LABEL_PX = 22;
  const LABEL_MAX = 32;

  function makeLabel(text, cat) {
    if (text.length > LABEL_MAX) text = text.slice(0, LABEL_MAX - 1).trimEnd() + '…';
    const c = document.createElement('canvas');
    const g = c.getContext('2d');
    const font = '600 30px -apple-system, system-ui, Segoe UI, sans-serif';
    g.font = font;
    const w = Math.ceil(g.measureText(text).width) + 36;
    c.width = w; c.height = 52;
    g.font = font;
    g.fillStyle = 'rgba(16,20,24,0.82)';
    const r = 12;
    g.beginPath();
    g.moveTo(r, 0); g.lineTo(w - r, 0); g.quadraticCurveTo(w, 0, w, r);
    g.lineTo(w, 52 - r); g.quadraticCurveTo(w, 52, w - r, 52);
    g.lineTo(r, 52); g.quadraticCurveTo(0, 52, 0, 52 - r);
    g.lineTo(0, r); g.quadraticCurveTo(0, 0, r, 0);
    g.fill();
    g.fillStyle = palette[cat] || '#9aa0a6';
    g.fillRect(0, 10, 7, 32);
    g.fillStyle = '#f2f4f6';
    g.textBaseline = 'middle';
    g.fillText(text, 20, 27);
    const tx = new THREE.CanvasTexture(c);
    tx.encoding = THREE.sRGBEncoding;
    const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: tx, depthTest: false, transparent: true, sizeAttenuation: false }));
    sprite.userData.aspect = w / 52;
    sprite.renderOrder = 10;
    return sprite;
  }

  // Sin atenuación, el tamaño del cartel va en fracción de la vista: se
  // recalcula con la cámara (perspectiva u ortográfica) y la ventana.
  function scaleLabels() {
    if (!labels.length) return;
    const { h } = size();
    const view = cam.isPerspectiveCamera
      ? 2 * Math.tan((cam.fov * Math.PI / 180) / 2)
      : (cam.top - cam.bottom) / cam.zoom;
    const s = LABEL_PX / Math.max(h, 1) * view;
    for (const l of labels) if (l.visible) l.scale.set(s * l.userData.aspect, s, 1);
  }

  function addLabel(id, name, cat, pos) {
    if (!id || !name) return;
    const sprite = makeLabel(String(name), cat);
    sprite.position.copy(pos);
    sprite.userData.id = id;
    labels.push(sprite);
    labelsGroup.add(sprite);
  }

  function updateLabels() {
    for (const l of labels) {
      const layerShown = l.userData.layer ? shown[l.userData.layer] !== false : true;
      l.visible = layerShown && (showNames || l.userData.id === selectedId);
    }
  }

  function load(sc) {
    dispose(root);
    dispose(labelsGroup);
    labelsGroup.clear();
    labels = [];
    scene.remove(root);
    root = new THREE.Group();
    scene.add(root);
    const keep = selectedId;
    cones = []; roofs = []; picks = [];
    highlight(null);
    selectedId = keep;
    L = {};
    for (const name of LAYERS) {
      L[name] = new THREE.Group();
      L[name].visible = shown[name];
      root.add(L[name]);
    }

    lastScene = sc;
    palette = sc.palette || {};
    // Luz real (F6.21.4): con la exposición de la cámara de IRIS, los focos
    // en candelas, el sol en lux y todo multiplicado por la misma escala que
    // usa el fotómetro, así que un foco al 50 % se ve la mitad. Sin nada
    // encendido (o con «Luz de trabajo») se ve con la luz de siempre.
    const anyLit = (sc.fixtures || []).some((f) => f.on && f.source && f.source.cd > 0);
    const env = (sc.environment && sc.environment.kind) || 'interior';
    const physical = !!(sc.exposure && sc.exposure.scale > 0 && sc.lightMode !== 'work' &&
      (anyLit || sc.sun));
    // Fondo según el entorno (F6.21.1): plató negro, exterior con cielo.
    scene.background = new THREE.Color(
      env === 'studio' ? '#050505'
        : env === 'exterior' ? (sc.sun ? '#9cbfdf' : '#0b1020')
        : baseBg);
    const k = physical ? sc.exposure.scale : 1;
    renderer.physicallyCorrectLights = physical;
    if (physical) {
      // Cielo de día (aprox. un cuarto del sol) o un poco de rebote de noche.
      // En un plató, solo los focos.
      if (env !== 'studio') {
        const skyLux = sc.sun ? (sc.sun.lux || 0) * 0.25 : 0.5;
        root.add(new THREE.HemisphereLight(0xdfe8f0, 0x3a3328, skyLux * k));
        root.add(new THREE.AmbientLight(0xffffff, 0.2 * k));
      }
    } else {
      root.add(new THREE.HemisphereLight(0xdfe8f0, 0x3a3328, sc.sun ? 0.6 : 0.38));
      root.add(new THREE.AmbientLight(0xffffff, 0.12));
    }
    post({ type: 'lightMode', physical, ev100: physical ? sc.exposure.ev100 : null });

    // Niebla o humo (F6.21.2): espesa la escena y hace visibles los haces.
    const fog = sc.fog && sc.fog.pct > 0 ? sc.fog : null;
    const fogAmount = fog ? fog.pct / 100 : 0;
    if (fog) {
      const perM = { haze: 0.06, smoke: 0.14, exterior: 0.03 }[fog.kind] || 0.06;
      const light = fog.day && env !== 'studio';
      scene.fog = new THREE.FogExp2(light ? 0xc9ced6 : 0x24272d, perM * fogAmount);
    } else {
      scene.fog = null;
    }

    // Lo que ocupa la escena, para el suelo y la cámara.
    const box = new THREE.Box3();
    const grow = (x, y, z) => box.expandByPoint(V(x, y, z || 0));
    (sc.halls || []).forEach((h) => h.outline.forEach((p) => grow(p[0], p[1], 0)));
    (sc.walls || []).forEach((w) => w.points.forEach((p, i) => grow(p[0], p[1], (w.z0 || 0) + w.tops[i])));
    (sc.trusses || []).forEach((t) => { grow(t.from[0], t.from[1], t.z); grow(t.to[0], t.to[1], t.z); });
    (sc.fixtures || []).forEach((f) => grow(f.pos[0], f.pos[1], f.pos[2]));
    (sc.pillars || []).forEach((p) => grow(p.at[0], p.at[1], p.heightM));
    (sc.people || []).forEach((p) => grow(p.at[0], p.at[1], 1.8));
    (sc.cameras || []).forEach((p) => grow(p.at[0], p.at[1], 1.6));
    (sc.props || []).forEach((p) => grow(p.at[0], p.at[1], (p.z0 || 0) + (p.heightM || 0.8)));
    const empty = box.isEmpty();
    msg.style.display = empty ? 'grid' : 'none';
    msg.textContent = 'La planta está vacía. Crea una nave con «Nave» en la paleta, o dibuja paredes, truss y luces: aparecerán aquí.';
    if (empty) box.set(V(-5, -5, 0), V(5, 5, 3));

    const c = box.getCenter(new THREE.Vector3());
    const sz = box.getSize(new THREE.Vector3());
    const span = Math.max(sz.x, sz.z, 6);
    // Suelo: gris neutro en plató, del terreno elegido fuera y, mucho más
    // grande, hasta el horizonte.
    const floorColor = env === 'studio' ? 0x767676
      : env === 'exterior' ? ((sc.environment && sc.environment.groundRgb) || 0x4f6b35)
      : 0x8a8378;
    const floorSpan = env === 'exterior' ? span + 400 : span + 30;
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(floorSpan, floorSpan), new THREE.MeshStandardMaterial({ color: floorColor, roughness: 0.95 }));
    floor.rotation.x = -Math.PI / 2;
    floor.position.set(c.x, -0.01, c.z);
    root.add(floor);
    const grid = new THREE.GridHelper(Math.ceil(span + 30), Math.ceil(span + 30), 0x6d7378, 0x7f858a);
    grid.position.set(c.x, 0, c.z);
    grid.material.transparent = true;
    grid.material.opacity = 0.25;
    root.add(grid);

    (sc.halls || []).forEach(addHall);
    (sc.walls || []).forEach(addWall);
    (sc.drapes || []).forEach(addDrape);

    for (const p of sc.pillars || []) {
      const h = p.heightM, z0 = p.z0 || 0;
      const geo = p.shape === 'round' ? new THREE.CylinderGeometry(p.sizeM / 2, p.sizeM / 2, h, 16) : new THREE.BoxGeometry(p.sizeM, h, p.sizeM);
      const m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color: 0xa9b0b6, metalness: 0.3, roughness: 0.6 }));
      m.position.copy(V(p.at[0], p.at[1], z0 + h / 2));
      m.userData.id = p.id; m.userData.movable = true; m.userData.dragY = z0; picks.push(m);
      L.pillars.add(m);
    }

    const trussById = {};
    for (const t of sc.trusses || []) {
      trussById[t.id] = t;
      L.rig.add(trussOf(t.from, t.to, t.z, t.profile, (t.sizeCm - 1) / 100, false, t.id));
    }

    const chain = new THREE.LineDashedMaterial({ color: 0x444444, dashSize: 0.06, gapSize: 0.04 });
    for (const r of sc.rigging || []) {
      const t = trussById[r.truss];
      const s = t ? (t.sizeCm - 1) / 100 : 0.29;
      const z = t ? t.z : 4;
      // Color por carga: verde holgado, ámbar al límite, rojo pasado.
      const ratio = r.loadKg !== undefined ? r.loadKg / Math.max(r.wllKg || 500, 1) : null;
      const loadMat = ratio === null ? null : new THREE.MeshStandardMaterial({ color: ratio > 1 ? 0xd9412b : ratio > 0.8 ? 0xe8a33c : 0x3f9b5f, roughness: 0.6 });
      if (r.type === 'motor') {
        const m = new THREE.Mesh(new THREE.BoxGeometry(0.26, 0.42, 0.26), loadMat || dark);
        m.position.copy(V(r.at[0], r.at[1], z + s + 0.26));
        m.userData.id = r.id; m.userData.movable = true; m.userData.dragY = z + s; picks.push(m);
        L.rig.add(m);
        const ln = new THREE.Line(new THREE.BufferGeometry().setFromPoints([V(r.at[0], r.at[1], z + s + 0.47), V(r.at[0], r.at[1], z + s + 2)]), chain);
        ln.computeLineDistances();
        L.rig.add(ln);
      } else {
        const z0 = r.z0 || 0;
        const tower = trussOf([r.at[0], r.at[1]], null, z + s + 0.25, 'square', 0.29, true, r.id);
        tower.position.y += z0;
        L.rig.add(tower);
        const base = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.05, 0.9), dark);
        base.position.copy(V(r.at[0], r.at[1], z0 + 0.025));
        L.rig.add(base);
        const sleeve = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.5, 0.42), loadMat || steel);
        sleeve.position.copy(V(r.at[0], r.at[1], z + s / 2));
        L.rig.add(sleeve);
      }
    }

    // Luces: el cuerpo, su cono y, hasta un máximo, luz de verdad.
    const fixtures = sc.fixtures || [];
    const maxLights = 14, step = Math.max(1, fixtures.length / maxLights);
    let next = 0, lit = 0;
    // Con un escaneo se ensaya la luz sobre la localización: los primeros
    // focos dan sombra (F6.12.4). Son caras, así que solo unos pocos.
    const hasScans = (sc.scans || []).length > 0;
    const maxShadows = 4;
    let shadows = 0;
    fixtures.forEach((f, i) => {
      const col = cctColor(f.cct || 3200);
      const p = V(f.pos[0], f.pos[1], f.pos[2]), a = V(f.aim[0], f.aim[1], f.aim[2]);
      const dir = new THREE.Vector3().subVectors(a, p).normalize();
      const body = new THREE.Group();
      body.position.copy(p);
      body.lookAt(a);
      const can = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.17, 0.4, 14), dark);
      can.rotation.x = Math.PI / 2;
      body.add(can);
      const lens = new THREE.Mesh(new THREE.CircleGeometry(0.13, 18), new THREE.MeshBasicMaterial({ color: f.on ? col : 0x333333 }));
      lens.position.z = 0.205;
      body.add(lens);
      body.name = (f.name || 'Foco') + ' · ' + f.id;
      body.userData.id = f.id; body.userData.movable = true; body.userData.dragY = p.y; body.userData.aim = a.clone(); picks.push(body);
      L.fixtures.add(body);
      if (!f.on) return;
      if (i >= next && lit < maxLights) {
        next += step; lit++;
        const half = clamp((f.beamDeg || 60) / 2, 5, 80) * Math.PI / 180;
        const sl = physical
          ? new THREE.SpotLight(col, ((f.source && f.source.cd) || 0) * k, 0, half, 0.45, 2)
          : new THREE.SpotLight(col, 0.6 + (f.watts || 500) / 1600, 0, half, 0.45, 1);
        sl.position.copy(p);
        sl.target.position.copy(a);
        if (hasScans && shadows < maxShadows) {
          shadows++;
          sl.castShadow = true;
          sl.shadow.mapSize.set(1024, 1024);
          sl.shadow.camera.near = 0.2;
          sl.shadow.camera.far = 40;
          sl.shadow.bias = -0.0008;
        }
        root.add(sl);
        root.add(sl.target);
      }
      if ((f.beamDeg || 360) >= 180) return;
      const t = Math.min(p.distanceTo(a), 14);
      const half = clamp((f.beamDeg || 60) / 2, 4, 62) * Math.PI / 180;
      const cg = new THREE.ConeGeometry(t * Math.tan(half), t, 36, 1, true);
      cg.translate(0, -t / 2, 0);
      // Con niebla, el haz se ve más (hasta unas tres veces).
      const beamOpacity = (f.beamDeg > 80 ? 0.05 : 0.11) * (1 + 2 * fogAmount);
      const cone = new THREE.Mesh(cg, new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: beamOpacity, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }));
      cone.position.copy(p);
      cone.quaternion.setFromUnitVectors(new THREE.Vector3(0, -1, 0), dir);
      cone.visible = showCones;
      cones.push(cone);
      root.add(cone);
    });

    const skin = new THREE.MeshStandardMaterial({ color: 0xdedad3, roughness: 0.8 });
    for (const q of sc.people || []) {
      const g = new THREE.Group();
      const b = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.14, 1.42, 10), skin);
      b.position.y = 0.71;
      const hd = new THREE.Mesh(new THREE.SphereGeometry(0.12, 12, 10), skin);
      hd.position.y = 1.6;
      g.add(b, hd);
      g.position.copy(V(q.at[0], q.at[1], q.z0 || 0));
      g.userData.id = q.id; g.userData.movable = true; g.userData.dragY = q.z0 || 0; picks.push(g);
      L.people.add(g);
    }
    for (const q of sc.cameras || []) {
      const g = new THREE.Group();
      g.add(new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.25, 0.35), dark));
      g.position.copy(V(q.at[0], q.at[1], (q.z0 || 0) + 1.5));
      g.lookAt(V(q.at[0] + q.dir[0], q.at[1] + q.dir[1], (q.z0 || 0) + 1.5));
      g.userData.id = q.id; g.userData.movable = true; g.userData.dragY = q.z0 || 0; picks.push(g);
      L.people.add(g);
    }
    for (const p of sc.props || []) {
      const thumb = p.thumb && thumbTex[p.thumb];
      // Con miniatura del asset, el bloque queda tenue y la foto va de
      // cartel, siempre de cara: el modelo real solo vive en Unreal.
      const mat = new THREE.MeshStandardMaterial({ color: catColor(p.cat), roughness: 0.75,
        transparent: !!thumb, opacity: thumb ? 0.18 : 1, depthWrite: !thumb });
      const g = propShape(p, mat);
      if (thumb) {
        const side = Math.max(p.sizeM || 0.5, p.heightM || 0.8) * 1.15;
        const card = new THREE.Sprite(new THREE.SpriteMaterial({ map: thumb, transparent: true }));
        card.scale.set(side, side, 1);
        card.position.y = side / 2;
        card.userData.thumb = true;
        g.add(card);
      }
      g.position.copy(V(p.at[0], p.at[1], p.z0 || 0));
      g.rotation.y = -(p.yawDeg || 0) * Math.PI / 180;
      g.name = (p.name || 'Pieza') + ' · ' + p.id;
      g.userData.id = p.id; g.userData.movable = true; g.userData.dragY = p.z0 || 0; picks.push(g);
      L.props.add(g);
    }

    // Etiquetas: encima de cada pieza.
    const tag = (list, layer, at) => (list || []).forEach((it) => {
      const n = labels.length;
      addLabel(it.id, it.name, it.cat, at(it));
      if (labels.length > n) labels[labels.length - 1].userData.layer = layer;
    });
    tag(sc.fixtures, 'fixtures', (f) => V(f.pos[0], f.pos[1], f.pos[2] + 0.45));
    tag(sc.people, 'people', (q) => V(q.at[0], q.at[1], (q.z0 || 0) + 2.0));
    tag(sc.cameras, 'people', (q) => V(q.at[0], q.at[1], (q.z0 || 0) + (q.z || 1.5) + 0.45));
    tag(sc.props, 'props', (p) => V(p.at[0], p.at[1], (p.z0 || 0) + (p.heightM || 0.8) + 0.3));
    tag(sc.pillars, 'pillars', (p) => V(p.at[0], p.at[1], (p.z0 || 0) + p.heightM + 0.3));
    tag(sc.trusses, 'rig', (t) => V((t.from[0] + t.to[0]) / 2, (t.from[1] + t.to[1]) / 2, t.z + 0.75));
    tag(sc.rigging, 'rig', (r) => V(r.at[0], r.at[1], (trussById[r.truss] ? trussById[r.truss].z : 4) + 1.0));
    tag(sc.walls, 'walls', (w) => {
      const k = Math.floor((w.points.length - 1) / 2);
      const a = w.points[k], b = w.points[Math.min(k + 1, w.points.length - 1)];
      return V((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (w.z0 || 0) + Math.max(...w.tops) + 0.3);
    });
    tag(sc.drapes, 'drapes', (d) => {
      const m = d.samples[Math.floor(d.samples.length / 2)];
      return V(m.p[0], m.p[1], (d.z0 || 0) + m.top + 0.3);
    });
    tag(sc.scans, null, (q) => V(q.at[0], q.at[1], (q.z0 || 0) + 0.5));
    updateLabels();

    // El sol, con sombras de lo que tapa.
    if (sc.sun) {
      const d = sc.sun.dir;
      const sun = new THREE.DirectionalLight(
        cctColor(sc.sun.cct || 5400),
        physical ? (sc.sun.lux || 0) * k : 1.5,
      );
      const reach = Math.max(sz.x, sz.z, 10) * 1.2;
      sun.position.copy(c).add(V(d[0], d[1], d[2]).multiplyScalar(reach * 2));
      sun.target.position.copy(c);
      sun.castShadow = true;
      sun.shadow.mapSize.set(2048, 2048);
      const sc2 = sun.shadow.camera;
      sc2.left = -reach; sc2.right = reach; sc2.top = reach; sc2.bottom = -reach;
      sc2.near = 0.5; sc2.far = reach * 5;
      sun.shadow.bias = -0.0005;
      root.add(sun, sun.target);
      root.traverse((o) => {
        if (!o.isMesh || (o.material && o.material.blending === THREE.AdditiveBlending)) return;
        o.castShadow = true;
        o.receiveShadow = true;
      });
      floor.castShadow = false;
    }

    if (hasScans && !sc.sun) {
      root.traverse((o) => {
        if (!o.isMesh || (o.material && o.material.blending === THREE.AdditiveBlending)) return;
        o.castShadow = true;
        o.receiveShadow = true;
      });
      floor.castShadow = false;
    }

    placeScans(sc.scans || []);

    const first = radius === 20 && center.lengthSq() === 0;
    center = c;
    radius = Math.max(sz.x, sz.z, sz.y * 2, 6) * 0.75;
    orthoFrustum();
    if (first) setView('iso', true);
    if (keep) highlight(keep);
    post({ type: 'loaded', fixtures: fixtures.length, lit });
  }

  function setView(v, instant) {
    if (typeof v === 'string' && v.startsWith('cam:')) {
      viewFromCamera(v.slice(4));
      return;
    }
    leaveCamera();
    const R = radius * 1.25, c = center;
    let to;
    if (v === 'top') to = new THREE.Vector3(c.x, c.y + R * 1.3, c.z + 0.001);
    else if (v === 'front') to = new THREE.Vector3(c.x, c.y + R * 0.15, c.z + R);
    else if (v === 'back') to = new THREE.Vector3(c.x, c.y + R * 0.15, c.z - R);
    else if (v === 'right') to = new THREE.Vector3(c.x + R, c.y + R * 0.15, c.z);
    else if (v === 'left') to = new THREE.Vector3(c.x - R, c.y + R * 0.15, c.z);
    else to = new THREE.Vector3(c.x + R * 0.62, c.y + R * 0.6, c.z + R * 0.78);
    post({ type: 'view', view: v });
    const from = cam.position.clone(), fromT = controls.target.clone();
    if (instant) {
      cam.position.copy(to);
      controls.target.copy(c);
      camO.zoom = 1;
      camO.updateProjectionMatrix();
      controls.update();
      return;
    }
    const t0 = performance.now();
    anim = (now) => {
      const k = clamp((now - t0) / 550, 0, 1);
      const e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
      cam.position.lerpVectors(from, to, e);
      controls.target.lerpVectors(fromT, c, e);
      if (k >= 1) anim = null;
    };
  }

  // ── Por la cámara ─────────────────────────────────────────────────────
  function viewFromCamera(id) {
    const q = lastScene && (lastScene.cameras || []).find((k) => k.id === id);
    if (!q) return;
    setOrtho(false);
    const aspect = 16 / 9;
    const hfov = (q.hfovDeg || 40) * Math.PI / 180;
    camView = { aspect, label: q.name + (q.lens ? ' · ' + q.lens : '') };
    // El campo vertical que da ese horizontal en 16:9, ajustado a la
    // ventana para que el marco quepa entero.
    const { w, h } = size();
    const vfovFrame = 2 * Math.atan(Math.tan(hfov / 2) / aspect);
    const boxH = Math.min(h * 0.9, (w * 0.9) / aspect);
    camP.fov = 2 * Math.atan(Math.tan(vfovFrame / 2) * h / boxH) * 180 / Math.PI;
    camP.updateProjectionMatrix();
    const z = (q.z0 || 0) + (q.z || 1.5);
    const pos = V(q.at[0], q.at[1], z);
    cam.position.copy(pos);
    controls.target.copy(V(q.at[0] + q.dir[0] * 5, q.at[1] + q.dir[1] * 5, z));
    controls.update();
    anim = null;
    placeFrame();
    post({ type: 'view', view: 'cam:' + id });
  }

  function placeFrame() {
    if (!camView) { frame.style.display = 'none'; return; }
    const { w, h } = size();
    const boxH = Math.min(h * 0.9, (w * 0.9) / camView.aspect);
    const boxW = boxH * camView.aspect;
    frame.style.display = 'block';
    frame.style.left = (w - boxW) / 2 + 'px';
    frame.style.top = (h - boxH) / 2 + 'px';
    frame.style.width = boxW + 'px';
    frame.style.height = boxH + 'px';
    frameLabel.textContent = camView.label;
  }

  function leaveCamera() {
    if (!camView) return;
    camView = null;
    camP.fov = 45;
    camP.updateProjectionMatrix();
    placeFrame();
  }

  // ── Medir ─────────────────────────────────────────────────────────────
  function clearMeasure() {
    measurePts = [];
    if (measureGroup) {
      scene.remove(measureGroup);
      dispose(measureGroup);
      measureGroup = null;
    }
  }

  function measureAt(e) {
    const r = rayAt(e);
    const hit = r.intersectObjects(root.children, true).find((i) => i.object.isMesh && visible(i.object) && i.object.material && i.object.material.blending !== THREE.AdditiveBlending);
    const p = hit ? hit.point.clone() : onPlane(e, 0);
    if (!p) return;
    if (measurePts.length >= 2) clearMeasure();
    measurePts.push(p);
    if (!measureGroup) { measureGroup = new THREE.Group(); scene.add(measureGroup); }
    const dot = new THREE.Mesh(new THREE.SphereGeometry(0.08, 12, 8), new THREE.MeshBasicMaterial({ color: 0xe8963f }));
    dot.position.copy(p);
    measureGroup.add(dot);
    if (measurePts.length === 2) {
      const [a, b] = measurePts;
      measureGroup.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints([a, b]), new THREE.LineBasicMaterial({ color: 0xe8963f })));
      const d = a.distanceTo(b);
      const dz = b.y - a.y;
      const dxy = Math.hypot(b.x - a.x, b.z - a.z);
      post({ type: 'measure', d, dz, dxy });
    }
  }

  // ── Luz en el suelo ───────────────────────────────────────────────────
  function setFloorLight(f) {
    if (floorLight) {
      scene.remove(floorLight);
      dispose(floorLight);
      floorLight = null;
    }
    if (!f) return;
    const img = new Image();
    img.onload = () => {
      const tx = new THREE.Texture(img);
      tx.needsUpdate = true;
      tx.encoding = THREE.sRGBEncoding;
      const w = f.x1 - f.x0, h = f.yTop - f.yBottom;
      const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: tx, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
      m.rotation.x = -Math.PI / 2;
      m.position.copy(V((f.x0 + f.x1) / 2, (f.yTop + f.yBottom) / 2, 0.02));
      if (floorLight) { scene.remove(floorLight); dispose(floorLight); }
      floorLight = m;
      scene.add(m);
    };
    img.src = 'data:image/png;base64,' + f.png;
  }

  // ── Escaneos ──────────────────────────────────────────────────────────
  function b64ToBuffer(b64) {
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out.buffer;
  }

  async function loadScan(file, format) {
    const bridge = window.flutter_inappwebview;
    if (!bridge) throw new Error('sin app');
    const b64 = await bridge.callHandler('iris', { type: 'scanData', file });
    if (!b64) throw new Error('El archivo del escaneo no está en esta máquina.');
    const buffer = b64ToBuffer(b64);
    if (format === 'obj') {
      return new THREE.OBJLoader().parse(new TextDecoder().decode(buffer));
    }
    if (format === 'ply') {
      const geo = new THREE.PLYLoader().parse(buffer);
      geo.computeBoundingBox();
      // Sin caras (una nube de puntos o un splat): puntos con su color.
      if (!geo.index) {
        return new THREE.Points(geo, new THREE.PointsMaterial({ size: 0.02, vertexColors: !!geo.attributes.color }));
      }
      geo.computeVertexNormals();
      return new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: !!geo.attributes.color, roughness: 0.9 }));
    }
    return await new Promise((resolve, reject) =>
      new THREE.GLTFLoader().parse(buffer, '', (g) => resolve(g.scene), reject));
  }

  // El escaneo recibe la luz de los focos y da sombra.
  function shadowed(obj) {
    if (obj) {
      obj.traverse((o) => {
        if (!o.isMesh) return;
        o.castShadow = true;
        o.receiveShadow = true;
      });
    }
    return obj;
  }

  function placeScans(list) {
    const keep = new Set(list.map((q) => q.id));
    for (const id of Object.keys(scanWrappers)) {
      if (!keep.has(id)) { scansGroup.remove(scanWrappers[id]); delete scanWrappers[id]; }
    }
    for (const q of list) {
      let w = scanWrappers[q.id];
      if (!w) {
        w = new THREE.Group();
        w.userData.id = q.id;
        w.userData.movable = true;
        w.userData.file = q.file;
        w.name = 'Escaneo · ' + q.id;
        scanWrappers[q.id] = w;
        scansGroup.add(w);
        if (!scanCache[q.file]) {
          scanCache[q.file] = loadScan(q.file, q.format).then(shadowed).catch((e) => {
            post({ type: 'scanError', id: q.id, message: String(e && e.message || e) });
            return null;
          });
        }
        scanCache[q.file].then((obj) => {
          if (obj && scanWrappers[q.id] === w) w.add(obj.clone());
        });
      }
      w.position.copy(V(q.at[0], q.at[1], q.z0 || 0));
      w.rotation.set(0, -(q.yawDeg || 0) * Math.PI / 180, 0);
      w.scale.setScalar(q.scale || 1);
      w.userData.dragY = q.z0 || 0;
      if (!picks.includes(w)) picks.push(w);
    }
  }

  function setOrtho(on) {
    const next = on ? camO : camP;
    if (next === cam) return;
    next.position.copy(cam.position);
    next.up.copy(cam.up);
    cam = next;
    controls.object = cam;
    camO.zoom = 1;
    orthoFrustum();
    controls.update();
  }

  function loop(now) {
    requestAnimationFrame(loop);
    if (anim) anim(now || performance.now());
    controls.update();
    if (selectedBox) selectedBox.update();
    scaleLabels();
    const { w, h } = size();
    renderer.setViewport(0, 0, w, h);
    renderer.setScissorTest(false);
    renderer.clear();
    renderer.render(scene, cam);
    const dir = new THREE.Vector3().subVectors(cam.position, controls.target).normalize();
    cubeCam.position.copy(dir.multiplyScalar(3.4));
    cubeCam.up.copy(cam.up);
    cubeCam.lookAt(0, 0, 0);
    renderer.setScissorTest(true);
    renderer.setScissor(w - M - CUBE, h - M - CUBE, CUBE, CUBE);
    renderer.setViewport(w - M - CUBE, h - M - CUBE, CUBE, CUBE);
    renderer.clearDepth();
    renderer.render(cubeScene, cubeCam);
    renderer.setScissorTest(false);
  }

  // glTF de lo que se ve, en base64, para exportar desde la app.
  // La estructura del set para Unreal (F6.21.3): paredes con sus huecos,
  // techos, cristales, telas, pilares y rigging, cada pieza con su sitio
  // metido en la propia malla (sin transformaciones de nodo), para que el
  // importador de Unreal la deje donde va aunque separe las piezas.
  function structureGlb() {
    const out = new THREE.Group();
    for (const g of [...roofs, L.walls, L.glass, L.drapes, L.pillars, L.rig].filter(Boolean)) {
      g.updateWorldMatrix(true, true);
      g.traverse((o) => {
        if (!o.isMesh || !o.geometry) return;
        const mat = o.material;
        if (mat && mat.blending === THREE.AdditiveBlending) return;
        const geo = o.geometry.clone();
        geo.applyMatrix4(o.matrixWorld);
        const m = new THREE.Mesh(geo, mat);
        m.name = o.name || 'IRIS';
        out.add(m);
      });
    }
    if (!out.children.length) return Promise.resolve(null);
    return new Promise((resolve, reject) => {
      new THREE.GLTFExporter().parse(out, (glb) => {
        const bytes = new Uint8Array(glb);
        let bin = '';
        for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
        resolve(btoa(bin));
      }, reject, { binary: true });
    });
  }

  function exportGlb(opts) {
    // Solo la estructura (para el MVR, que lleva los focos aparte), o todo.
    const what = opts && opts.structure
      ? [...roofs, L.walls, L.glass, L.drapes, L.pillars, L.rig].filter(Boolean)
      : [root, scansGroup];
    return new Promise((resolve, reject) => {
      new THREE.GLTFExporter().parse(what, (glb) => {
        const bytes = new Uint8Array(glb);
        let bin = '';
        for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
        resolve(btoa(bin));
      }, reject, { binary: true });
    });
  }

  // Cenital ortográfica de un escaneo, a escala, con fondo transparente:
  // la app la pone de fondo en la planta para calcar (F6.12.3). Devuelve
  // el PNG y su rectángulo en metros de la planta (x a la derecha, y hacia
  // abajo, como el lienzo).
  function scanTop(id, maxPx) {
    const w = scanWrappers[id];
    if (!w || !w.children.length) return null;
    w.updateWorldMatrix(true, true);
    const box = new THREE.Box3().setFromObject(w);
    if (box.isEmpty()) return null;
    const sx = box.max.x - box.min.x, sz = box.max.z - box.min.z;
    if (!(sx > 0 && sz > 0)) return null;
    const long = Math.max(sx, sz);
    const px = Math.max(256, Math.min(maxPx || 2048, 4096));
    const W = Math.max(1, Math.round(px * sx / long));
    const H = Math.max(1, Math.round(px * sz / long));
    const tmp = new THREE.Scene();
    const copy = w.clone(true);
    w.matrixWorld.decompose(copy.position, copy.quaternion, copy.scale);
    tmp.add(copy);
    tmp.add(new THREE.AmbientLight(0xffffff, 0.9));
    const sunTop = new THREE.DirectionalLight(0xffffff, 0.5);
    sunTop.position.set(0, 1, 0);
    tmp.add(sunTop);
    const cx = (box.min.x + box.max.x) / 2, cz = (box.min.z + box.max.z) / 2;
    const top = new THREE.OrthographicCamera(-sx / 2, sx / 2, sz / 2, -sz / 2, 0.01, 1000);
    top.position.set(cx, box.max.y + 10, cz);
    top.up.set(0, 0, -1);
    top.lookAt(cx, box.min.y, cz);
    const target = new THREE.WebGLRenderTarget(W, H);
    target.texture.encoding = THREE.sRGBEncoding;
    const clear = new THREE.Color();
    renderer.getClearColor(clear);
    const alpha = renderer.getClearAlpha();
    renderer.setRenderTarget(target);
    renderer.setViewport(0, 0, W, H);
    renderer.setScissorTest(false);
    renderer.setClearColor(0x000000, 0);
    renderer.clear();
    renderer.render(tmp, top);
    const pixels = new Uint8Array(W * H * 4);
    renderer.readRenderTargetPixels(target, 0, 0, W, H, pixels);
    renderer.setRenderTarget(null);
    renderer.setClearColor(clear, alpha);
    target.dispose();
    const canvas = document.createElement('canvas');
    canvas.width = W;
    canvas.height = H;
    const ctx = canvas.getContext('2d');
    const img = ctx.createImageData(W, H);
    // WebGL lee de abajo arriba: se da la vuelta.
    for (let y = 0; y < H; y++) {
      img.data.set(pixels.subarray((H - 1 - y) * W * 4, (H - y) * W * 4), y * W * 4);
    }
    ctx.putImageData(img, 0, 0);
    return JSON.stringify({
      png: canvas.toDataURL('image/png').split(',')[1],
      // En three, x es la x de la planta y z su y hacia abajo, en metros.
      x: box.min.x, y: box.min.z, w: sx, h: sz,
    });
  }

  window.iris = {
    load,
    scanTop,
    // Un escaneo que acaba de llegar a este equipo: se olvida lo cargado (o
    // el fallo) y se vuelve a pedir con la escena de antes.
    rescan: (file) => {
      delete scanCache[file];
      for (const id of Object.keys(scanWrappers)) {
        const w = scanWrappers[id];
        if (w.userData.file !== file) continue;
        scansGroup.remove(w);
        const i = picks.indexOf(w);
        if (i >= 0) picks.splice(i, 1);
        delete scanWrappers[id];
      }
      if (lastScene) load(lastScene);
    },
    view: (v) => setView(v),
    select: (id) => highlight(id),
    floor: (f) => setFloorLight(f),
    exportGlb,
    structureGlb,
    // Miniaturas que manda la app: {clave: dataURL}. El atrezzo se rehace
    // con ellas cuando están cargadas.
    thumbs: (map) => {
      const keys = Object.keys(map || {});
      let pending = keys.length;
      for (const key of keys) {
        const img = new Image();
        img.onload = () => {
          const tx = new THREE.Texture(img);
          tx.encoding = THREE.sRGBEncoding;
          tx.needsUpdate = true;
          if (thumbTex[key]) thumbTex[key].dispose();
          thumbTex[key] = tx;
          if (--pending === 0 && lastScene) load(lastScene);
        };
        img.onerror = () => { if (--pending === 0 && lastScene) load(lastScene); };
        img.src = map[key];
      }
    },
    set: (o) => {
      if ('cones' in o) { showCones = !!o.cones; cones.forEach((c) => (c.visible = showCones)); }
      if ('roof' in o) { showRoof = !!o.roof; roofs.forEach((r) => (r.visible = showRoof)); }
      if ('ortho' in o) setOrtho(!!o.ortho);
      if (o.bg) {
        baseBg = o.bg;
        const env = lastScene && lastScene.environment && lastScene.environment.kind;
        if (!env || env === 'interior') scene.background = new THREE.Color(o.bg);
      }
      if ('names' in o) { showNames = !!o.names; updateLabels(); }
      if ('measure' in o) {
        measuring = !!o.measure;
        if (!measuring) clearMeasure();
      }
      if (o.show) {
        for (const name of LAYERS) {
          if (name in o.show) {
            shown[name] = !!o.show[name];
            if (L[name]) L[name].visible = shown[name];
          }
        }
        // Sin focos no hay conos.
        if ('fixtures' in o.show) cones.forEach((c) => (c.visible = showCones && shown.fixtures));
        updateLabels();
      }
    },
  };

  resize();
  loop();
  msg.textContent = 'Esperando la planta…';
  post({ type: 'ready' });
})();
