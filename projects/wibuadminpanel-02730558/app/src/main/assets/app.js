(() => {
  'use strict';

  const SB_URL = 'https://fdbwrqmtewoymugfssjk.supabase.co';
  const SB_KEY = 'sb_publishable_bx9-9nIaMoiLLiqsgWlMVw_RR9BmkPQ';
  // Batas kuota untuk indikator server (sesuaikan dengan paket Supabase kamu)
  const LIMITS = { db: 500 * 1024 * 1024, storage: 1024 * 1024 * 1024 };
  const REASON = { name: 'reason', label: 'Alasan (wajib, min 3 karakter)', required: true, minlength: 3, maxlength: 200, placeholder: 'Contoh: hadiah event' };

  const sb = supabase.createClient(SB_URL, SB_KEY, {
    auth: { flowType: 'pkce', persistSession: true, autoRefreshToken: true, detectSessionInUrl: false }
  });

  let ME = null;
  let CLANS = [];

  /* ---------- Util ---------- */
  const $ = (s, r = document) => r.querySelector(s);
  const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const num = v => Number(v ?? 0).toLocaleString('id-ID');
  const dateId = v => (v ? new Date(v).toLocaleString('id-ID') : '—');
  const bytes = b => {
    if (b == null) return '—';
    let n = Number(b), i = 0;
    const u = ['B', 'KB', 'MB', 'GB', 'TB'];
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
    return n.toFixed(i ? 2 : 0) + ' ' + u[i];
  };
  const parseId = v => {
    const n = Number(String(v ?? '').trim());
    if (!Number.isInteger(n) || n < 1) throw new Error('ID # harus angka bulat positif');
    return n;
  };
  const parseWhole = (v, label) => {
    const n = Number(String(v ?? '').trim());
    if (!Number.isSafeInteger(n)) throw new Error(label + ' harus angka bulat');
    return n;
  };
  function toast(msg, ok = true) {
    const t = $('#toast');
    t.textContent = msg;
    t.className = 'toast show ' + (ok ? 'ok' : 'err');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.remove('show'), 3200);
  }
  async function rpc(fn, args = {}) {
    const { data, error } = await sb.rpc(fn, args);
    if (error) throw new Error(error.message || 'Terjadi kesalahan');
    return data;
  }

  /* ---------- Gate & login ---------- */
  function showGate(msg = '') {
    $('#app').classList.add('hidden');
    $('#gate').classList.remove('hidden');
    $('#gateMsg').textContent = msg;
  }
  function showApp() {
    $('#gate').classList.add('hidden');
    $('#app').classList.remove('hidden');
  }

  async function boot() {
    let session = null;
    try {
      ({ data: { session } } = await sb.auth.getSession());
    } catch (e) { return showGate('Gagal memuat sesi: ' + e.message); }
    if (!session) return showGate();
    try {
      ME = await rpc('admin_me');
    } catch (e) {
      if (/Akses ditolak/i.test(e.message)) {
        await sb.auth.signOut();
        ME = null;
        return showGate('Akun ini bukan Developer / Admin.');
      }
      return showGate('Gagal memeriksa akses: ' + e.message);
    }
    $('#whoami').innerHTML = `<span class="pill" style="--c:${esc(ME.color || '#2196F3')}">${esc(ME.label || 'Staff')}</span>
      <strong>${esc(ME.username || 'Staff')}</strong> <span class="muted">#${num(ME.number)}</span>`;
    showApp();
    route();
  }

  async function login() {
    $('#gateMsg').textContent = 'Membuka Google…';
    const { data, error } = await sb.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: 'wibuadmin://auth-callback', skipBrowserRedirect: true }
    });
    if (error || !data?.url) return showGate('Gagal memulai login: ' + (error?.message || 'URL kosong'));
    if (window.AndroidBridge) AndroidBridge.openExternal(data.url);
    else showGate('Buka panel ini lewat APK untuk login.');
  }

  // Dipanggil APK setelah Google mengembalikan kode ke wibuadmin://auth-callback
  window.onOAuthCallback = async url => {
    try {
      const code = new URL(url).searchParams.get('code');
      if (!code) throw new Error('kode login tidak ditemukan');
      const { error } = await sb.auth.exchangeCodeForSession(code);
      if (error) throw error;
      await boot();
    } catch (e) { showGate('Login gagal: ' + e.message); }
  };

  async function logout() {
    await sb.auth.signOut();
    ME = null;
    showGate('Kamu sudah keluar.');
  }

  /* ---------- Router ---------- */
  const NAV = [
    ['dash', 'Dashboard'], ['id', 'Panel ID'], ['clan', 'Panel Clan'], ['role', 'Panel Role'],
    ['wbm', 'Panel WBM'], ['xp', 'Panel XP/LVL'], ['block', 'Panel Blokir'], ['server', 'Info Server'], ['log', 'Log Admin']
  ];
  const VIEWS = {};

  function renderNav() {
    $('#nav').innerHTML = NAV.map(([k, l]) => `<a href="#${k}" data-nav="${k}">${esc(l)}</a>`).join('');
  }
  function route() {
    const key = location.hash.replace('#', '') || 'dash';
    const v = VIEWS[key] ? key : 'dash';
    document.querySelectorAll('[data-nav]').forEach(a => a.classList.toggle('active', a.dataset.nav === v));
    $('#view').innerHTML = '<div class="loading">Memuat…</div>';
    Promise.resolve().then(() => VIEWS[v]()).catch(e => {
      $('#view').innerHTML = `<div class="card glass err">Gagal memuat: ${esc(e.message)}</div>`;
    });
  }
  const head = (title, desc = '') => `<div class="page-head"><div><h2>${esc(title)}</h2>${desc ? `<p class="muted">${esc(desc)}</p>` : ''}</div></div>`;
  const mount = (html, bind) => { $('#view').innerHTML = html; if (bind) bind(); };

  /* ---------- Komponen form ---------- */
  function inputHtml(f) {
    const attrs = [
      f.required ? 'required' : '',
      f.min != null ? `min="${f.min}"` : '',
      f.max != null ? `max="${f.max}"` : '',
      f.minlength ? `minlength="${f.minlength}"` : '',
      f.maxlength ? `maxlength="${f.maxlength}"` : '',
      f.placeholder ? `placeholder="${esc(f.placeholder)}"` : ''
    ].join(' ');
    if (f.type === 'select') {
      const opts = f.options.map(o => `<option value="${esc(o.v)}"${String(o.v) === String(f.value ?? '') ? ' selected' : ''}>${esc(o.l)}</option>`).join('');
      return `<select name="${f.name}" ${f.required ? 'required' : ''}>${opts}</select>`;
    }
    return `<input name="${f.name}" type="${f.type || 'text'}" value="${esc(f.value ?? '')}" ${attrs} autocomplete="off">`;
  }
  const fieldRow = f => `<label class="field"><span>${esc(f.label)}</span>${inputHtml(f)}</label>`;

  function formView({ title, desc, top = '', fields, submit, idField = true, btn = 'Jalankan' }) {
    mount(`${head(title, desc)}${top}
      <div class="split">
        <form class="card glass form" id="af">
          ${fields.map(fieldRow).join('')}
          <p class="msg" id="afMsg"></p>
          <button class="btn primary" type="submit">${esc(btn)}</button>
        </form>
        <div class="card glass" id="tcard"><p class="muted">Isi ID # untuk melihat data pengguna.</p></div>
      </div>`, () => {
        const form = $('#af');
        const numIn = idField ? form.elements.namedItem('number') : null;
        if (numIn) numIn.addEventListener('change', () => showTarget(numIn.value));
        form.addEventListener('submit', async e => {
          e.preventDefault();
          const btnEl = form.querySelector('button[type=submit]');
          btnEl.disabled = true;
          $('#afMsg').textContent = '';
          try {
            const vals = Object.fromEntries(new FormData(form).entries());
            toast(await submit(vals));
            if (numIn) showTarget(numIn.value);
          } catch (err) {
            toast(err.message, false);
            $('#afMsg').textContent = err.message;
          } finally { btnEl.disabled = false; }
        });
      });
  }

  function openModal(title, fields, submit) {
    $('#mTitle').textContent = title;
    const f = $('#mForm');
    f.innerHTML = fields.map(fieldRow).join('') + `<p class="msg" id="mMsg"></p>
      <div class="row-end"><button type="button" class="btn ghost" data-close>Batal</button>
      <button class="btn primary" type="submit">Simpan</button></div>`;
    $('#modal').classList.remove('hidden');
    f.onsubmit = async e => {
      e.preventDefault();
      const btn = f.querySelector('[type=submit]');
      btn.disabled = true;
      try {
        const vals = Object.fromEntries(new FormData(f).entries());
        const msg = await submit(vals);
        closeModal();
        toast(msg);
        route();
      } catch (err) {
        const m = $('#mMsg');
        if (m) m.textContent = err.message;
        btn.disabled = false;
      }
    };
  }
  function closeModal() {
    $('#modal').classList.add('hidden');
    $('#mForm').innerHTML = '';
  }

  /* ---------- Kartu target ---------- */
  async function showTarget(raw) {
    const card = $('#tcard');
    if (!card) return;
    let n;
    try { n = parseId(raw); } catch { card.innerHTML = '<p class="muted">Masukkan ID # yang valid.</p>'; return; }
    card.innerHTML = '<p class="muted">Memuat…</p>';
    try {
      const rows = await rpc('admin_search_users', { p_q: String(n) });
      const u = rows.find(r => Number(r.number) === n);
      card.innerHTML = u ? userCard(u) : '<p class="muted">ID tidak ditemukan.</p>';
    } catch (e) { card.innerHTML = `<p class="err">${esc(e.message)}</p>`; }
  }
  function userCard(u) {
    return `<div class="ucard">
      <div class="avatar">${esc((u.username || '?').charAt(0).toUpperCase())}</div>
      <div><strong>${esc(u.username)}</strong> <span class="muted">#${num(u.number)}</span></div>
      <div class="pills">
        ${u.role ? `<span class="pill">${esc(u.role)}</span>` : '<span class="pill ghost">tanpa role</span>'}
        ${u.premium ? '<span class="pill blue">premium</span>' : ''}
        ${u.blocked ? '<span class="pill red">diblokir</span>' : ''}
      </div></div>
      <dl class="kv">
        <dt>Email</dt><dd>${esc(u.email || '—')}</dd>
        <dt>Level</dt><dd>${num(u.level)}</dd>
        <dt>XP</dt><dd>${num(u.xp)}</dd>
        <dt>WBM</dt><dd>${num(u.wbm)}</dd>
        <dt>Clan</dt><dd>${esc(u.clan || '—')}</dd>
      </dl>`;
  }
  function usersTable(rows) {
    return `<div class="tbl"><table><thead><tr>
      <th>ID</th><th>Nama</th><th>Role</th><th>Lvl</th><th>XP</th><th>WBM</th><th>Clan</th><th>Status</th>
      </tr></thead><tbody>
      ${rows.map(u => `<tr><td>#${num(u.number)}</td><td>${esc(u.username)}</td><td>${esc(u.role || '—')}</td>
        <td>${num(u.level)}</td><td>${num(u.xp)}</td><td>${num(u.wbm)}</td><td>${esc(u.clan || '—')}</td>
        <td>${u.blocked ? '<span class="pill red">blokir</span>' : (u.premium ? '<span class="pill blue">premium</span>' : 'normal')}</td></tr>`).join('')}
      </tbody></table></div>`;
  }

  /* ---------- Dashboard & info ---------- */
  const stat = (label, value, sub = '') => `<div class="stat glass"><span>${esc(label)}</span><strong>${value}</strong>${sub ? `<small>${esc(sub)}</small>` : ''}</div>`;
  function gauge(label, used, limit) {
    const p = Math.min(100, (Number(used || 0) / limit) * 100);
    return `<div class="gauge"><div class="gauge-top"><span>${esc(label)}</span><span>${bytes(used)} / ${bytes(limit)}</span></div>
      <div class="bar"><i style="width:${p.toFixed(1)}%"></i></div></div>`;
  }
  function bars(tables) {
    const list = tables || [];
    if (!list.length) return '<p class="muted">Belum ada data.</p>';
    const max = Math.max(1, ...list.map(t => Number(t.bytes || 0)));
    return list.map(t => `<div class="brow"><span>${esc(t.name)}</span>
      <div class="bar"><i style="width:${(Number(t.bytes || 0) / max * 100).toFixed(1)}%"></i></div>
      <small class="muted">${bytes(t.bytes)} · ${num(t.row_count)} baris</small></div>`).join('');
  }

  VIEWS.dash = async () => {
    const s = await rpc('admin_server_info');
    const st = s.storage || {};
    mount(`${head('Dashboard', `Halo, ${ME?.username || 'Staff'}. Ringkasan hari ini.`)}
      <div class="stats">
        ${stat('Pengguna', num(s.users), `+${num(s.new_users_7d)} dalam 7 hari`)}
        ${stat('Premium aktif', num(s.premium_active))}
        ${stat('Clan', num(s.clans), `${num(s.clan_members)} anggota`)}
        ${stat('Total WBM', num(s.wbm_total))}
        ${stat('Blokir aktif', num(s.blocks_active))}
        ${stat('Aksi admin 24 jam', num(s.admin_actions_24h))}
      </div>
      <div class="split">
        <div class="card glass">${gauge('Database', s.db_bytes, LIMITS.db)}${gauge('Storage file', st.bytes, LIMITS.storage)}</div>
        <div class="card glass"><h3>Tabel terbesar</h3>${bars((s.tables || []).slice(0, 5))}</div>
      </div>
      <p class="muted small">Diperbarui ${esc(dateId(s.server_time))}</p>`);
  };

  VIEWS.server = async () => {
    const s = await rpc('admin_server_info');
    const st = s.storage || {};
    mount(`${head('Info Server', 'Pemakaian database dan storage Supabase.')}
      <div class="card glass"><h3>Database</h3>${gauge('Database', s.db_bytes, LIMITS.db)}</div>
      <div class="card glass"><h3>Storage file</h3>${gauge('Storage', st.bytes, LIMITS.storage)}
        <p class="muted small">${num(st.objects)} file</p></div>
      <div class="card glass"><h3>Tabel terbesar</h3>${bars(s.tables)}</div>
      <div class="card glass"><h3>Detail</h3><dl class="kv">
        <dt>PostgreSQL</dt><dd>${esc(s.pg_version)}</dd>
        <dt>Waktu server</dt><dd>${esc(dateId(s.server_time))}</dd>
        <dt>Pengguna</dt><dd>${num(s.users)}</dd>
        <dt>Pesan chat</dt><dd>${num(s.chat_messages)}</dd>
        <dt>Komentar</dt><dd>${num(s.comments)}</dd>
        <dt>Riwayat tonton</dt><dd>${num(s.watch_rows)}</dd>
        <dt>Total WBM</dt><dd>${num(s.wbm_total)}</dd>
      </dl></div>`);
  };

  VIEWS.log = async () => {
    const rows = await rpc('admin_logs', { p_limit: 100 });
    mount(`${head('Log Admin', '100 aksi terakhir. Log tidak bisa dihapus dari panel.')}
      <div class="card glass"><div class="tbl"><table><thead><tr>
        <th>Waktu</th><th>Oleh</th><th>Aksi</th><th>Target</th><th>Detail</th></tr></thead><tbody>
        ${rows.length ? rows.map(r => `<tr><td>${esc(dateId(r.created_at))}</td><td>${esc(r.actor || '—')}</td>
          <td><span class="pill">${esc(r.action)}</span></td>
          <td>${r.target ? `${esc(r.target)} <span class="muted">#${num(r.target_number)}</span>` : '—'}</td>
          <td>${esc(r.detail)}</td></tr>`).join('')
          : '<tr><td colspan="5" class="muted">Belum ada aksi.</td></tr>'}
      </tbody></table></div></div>`);
  };

  /* ---------- Panel ID ---------- */
  VIEWS.id = () => {
    const isDev = (ME?.priority ?? 0) >= 100;
    const idForm = isDev ? `<div class="card glass"><h3>Ubah ID #</h3>
      <p class="muted small">Khusus Developer. ID baru harus belum dipakai.</p>
      <form id="cid" class="form">
        <label class="field"><span>ID lama #</span><input name="old" type="number" min="1" required></label>
        <label class="field"><span>ID baru #</span><input name="new" type="number" min="1" max="2000000000" required></label>
        ${fieldRow(REASON)}
        <p class="msg" id="cidMsg"></p>
        <button class="btn primary" type="submit">Ubah ID</button>
      </form></div>` : '';
    mount(`${head('Panel ID', 'Cari pengguna berdasarkan ID #, nama, atau email.')}
      <form class="search card glass" id="sf"><input id="sq" placeholder="ID # / nama / email" autocomplete="off"><button class="btn primary" type="submit">Cari</button></form>
      <div id="sres" class="card glass"><p class="muted">Ketik lalu tekan Cari.</p></div>
      ${idForm}`, () => {
      $('#sf').addEventListener('submit', async e => {
        e.preventDefault();
        const box = $('#sres');
        box.innerHTML = '<p class="muted">Mencari…</p>';
        try {
          const rows = await rpc('admin_search_users', { p_q: $('#sq').value.trim() });
          box.innerHTML = rows.length ? usersTable(rows) : '<p class="muted">Tidak ada hasil.</p>';
        } catch (err) { box.innerHTML = `<p class="err">${esc(err.message)}</p>`; }
      });
      const cid = $('#cid');
      if (cid) cid.addEventListener('submit', async e => {
        e.preventDefault();
        const btn = cid.querySelector('button');
        btn.disabled = true;
        try {
          const msg = await rpc('admin_change_user_id', {
            p_old: parseId(cid.elements.namedItem('old').value),
            p_new: parseId(cid.elements.namedItem('new').value),
            p_reason: cid.elements.namedItem('reason').value
          });
          toast(msg);
          cid.reset();
          $('#cidMsg').textContent = '';
        } catch (err) {
          toast(err.message, false);
          $('#cidMsg').textContent = err.message;
        } finally { btn.disabled = false; }
      });
    });
  };

  /* ---------- Panel Role ---------- */
  VIEWS.role = async () => {
    const roles = await rpc('admin_roles');
    const list = roles.length
      ? roles.map(r => `<div class="role-row"><i style="background:${esc(r.color)}"></i><strong>${esc(r.label)}</strong>
          <code>${esc(r.key)}</code><span class="muted">prioritas ${num(r.priority)}</span></div>`).join('')
      : '<p class="muted">Tidak ada role yang bisa kamu berikan.</p>';
    formView({
      title: 'Panel Role',
      desc: 'Beri atau cabut role. Role setara atau lebih tinggi dari role kamu tidak bisa diberikan.',
      top: `<div class="card glass"><h3>Role yang bisa kamu berikan</h3>${list}</div>`,
      fields: [
        { name: 'number', label: 'ID #', type: 'number', min: 1, required: true },
        { name: 'role', label: 'Role baru', type: 'select', value: '', options: [{ v: '', l: 'Tanpa role' }, ...roles.map(r => ({ v: r.key, l: r.label }))] },
        REASON
      ],
      btn: 'Simpan role',
      submit: v => rpc('admin_set_role', { p_number: parseId(v.number), p_role: v.role || null, p_reason: v.reason })
    });
  };

  /* ---------- Panel WBM ---------- */
  VIEWS.wbm = () => formView({
    title: 'Panel WBM',
    desc: 'Tambah atau kurangi WBM pengguna. Saldo tidak bisa minus dan setiap aksi tercatat.',
    fields: [
      { name: 'number', label: 'ID #', type: 'number', min: 1, required: true },
      { name: 'op', label: 'Aksi', type: 'select', value: 'tambah', options: [{ v: 'tambah', l: 'Tambah' }, { v: 'kurangi', l: 'Kurangi' }] },
      { name: 'amount', label: 'Jumlah WBM', type: 'number', min: 1, required: true },
      REASON
    ],
    btn: 'Terapkan WBM',
    submit: v => {
      const n = parseId(v.number);
      const amt = parseWhole(v.amount, 'Jumlah');
      if (amt < 1) throw new Error('Jumlah harus lebih dari 0');
      return rpc('admin_grant_wbm', { p_number: n, p_amount: v.op === 'kurangi' ? -amt : amt, p_reason: v.reason });
    }
  });

  /* ---------- Panel XP / LVL ---------- */
  VIEWS.xp = () => formView({
    title: 'Panel XP / LVL',
    desc: 'Atur XP pengguna. Level dihitung otomatis dari XP sesuai kurva level server.',
    fields: [
      { name: 'number', label: 'ID #', type: 'number', min: 1, required: true },
      { name: 'xp', label: 'XP baru (0 sampai batas)', type: 'number', min: 0, required: true },
      REASON
    ],
    btn: 'Simpan XP',
    submit: v => {
      const xp = parseWhole(v.xp, 'XP');
      if (xp < 0) throw new Error('XP tidak boleh negatif');
      return rpc('admin_set_xp', { p_number: parseId(v.number), p_xp: xp, p_reason: v.reason });
    }
  });

  /* ---------- Panel Blokir ---------- */
  function unblockFlow(n) {
    openModal(`Buka blokir #${n}`, [REASON], async v => {
      return rpc('admin_unblock', { p_number: n, p_reason: v.reason });
    });
  }
  VIEWS.block = async () => {
    const rows = await rpc('admin_list_blocks');
    const list = rows.length
      ? `<div class="tbl"><table><thead><tr><th>ID</th><th>Nama</th><th>Alasan</th><th>Berakhir</th><th>Oleh</th><th></th></tr></thead><tbody>
        ${rows.map(b => `<tr><td>#${num(b.number)}</td><td>${esc(b.username)}</td><td>${esc(b.reason)}</td>
          <td>${b.expires_at ? esc(dateId(b.expires_at)) : '<span class="pill red">permanen</span>'}</td>
          <td>${esc(b.blocked_by || '—')}</td>
          <td><button class="btn ghost small" data-unblock="${Number(b.number)}">Buka</button></td></tr>`).join('')}
        </tbody></table></div>`
      : '<p class="muted">Tidak ada blokir aktif.</p>';
    formView({
      title: 'Panel Blokir',
      desc: 'Blokir membatasi chat, komentar, dan join clan. Durasi "Permanen" tidak punya batas waktu.',
      top: `<div class="card glass"><h3>Blokir aktif</h3>${list}</div>`,
      fields: [
        { name: 'number', label: 'ID #', type: 'number', min: 1, required: true },
        { name: 'hours', label: 'Durasi', type: 'select', value: '24', options: [
          { v: '1', l: '1 jam' }, { v: '24', l: '1 hari' }, { v: '168', l: '7 hari' }, { v: '720', l: '30 hari' }, { v: '', l: 'Permanen' }
        ] },
        REASON
      ],
      btn: 'Blokir',
      submit: v => rpc('admin_block', { p_number: parseId(v.number), p_hours: v.hours ? Number(v.hours) : null, p_reason: v.reason })
    });
  };

  /* ---------- Panel Clan ---------- */
  VIEWS.clan = () => {
    mount(`${head('Panel Clan', 'Atur WBM Clan tanpa setor, tier, dan nama clan. Semua aksi tercatat.')}
      <form class="search card glass" id="cf"><input id="cq" placeholder="Nama / tag / ID leader" autocomplete="off"><button class="btn primary" type="submit">Cari</button></form>
      <div id="clist" class="card glass"><div class="loading">Memuat…</div></div>`, () => {
      $('#cf').addEventListener('submit', e => { e.preventDefault(); loadClans($('#cq').value.trim()); });
      loadClans('');
    });
  };
  async function loadClans(q) {
    const box = $('#clist');
    if (!box) return;
    try {
      CLANS = await rpc('admin_list_clans', { p_q: q });
      box.innerHTML = CLANS.length ? `<div class="tbl"><table><thead><tr>
        <th>Clan</th><th>Tag</th><th>Tier</th><th>WBM Clan</th><th>XP</th><th>Slot</th><th>Anggota</th><th>Leader</th><th>Aksi</th>
        </tr></thead><tbody>
        ${CLANS.map(c => `<tr><td>${esc(c.name)}</td><td><code>${esc(c.tag)}</code></td><td>${num(c.tier)}</td>
          <td>${num(c.wbm_clan)}</td><td>${num(c.xp)}</td><td>${num(c.slots)}</td><td>${num(c.members)}</td>
          <td>${esc(c.leader_name)} <span class="muted">#${num(c.leader_number)}</span></td>
          <td class="acts">
            <button class="btn ghost small" data-clan-act="wbm" data-id="${Number(c.id)}">WBM</button>
            <button class="btn ghost small" data-clan-act="xp" data-id="${Number(c.id)}">XP</button>
            <button class="btn ghost small" data-clan-act="tier" data-id="${Number(c.id)}">Tier</button>
            <button class="btn ghost small" data-clan-act="rename" data-id="${Number(c.id)}">Nama</button>
          </td></tr>`).join('')}
        </tbody></table></div>` : '<p class="muted">Clan tidak ditemukan.</p>';
    } catch (e) { box.innerHTML = `<p class="err">${esc(e.message)}</p>`; }
  }
  function clanAction(act, id) {
    const c = CLANS.find(x => Number(x.id) === id);
    if (!c) return toast('Data clan kedaluwarsa, muat ulang', false);
    if (act === 'wbm') return openModal(`WBM Clan · ${c.name}`, [
      { name: 'amount', label: `WBM Clan baru (sekarang ${num(c.wbm_clan)})`, type: 'number', min: 0, required: true, value: c.wbm_clan },
      REASON
    ], async v => {
      await rpc('admin_set_clan_wbm', { p_clan: id, p_amount: parseWhole(v.amount, 'WBM Clan'), p_reason: v.reason });
      return 'WBM Clan diperbarui';
    });
    if (act === 'tier') return openModal(`Tier · ${c.name}`, [
      { name: 'tier', label: `Tier baru 1-30 (sekarang ${c.tier})`, type: 'number', min: 1, max: 30, required: true, value: c.tier },
      REASON
    ], async v => {
      await rpc('admin_set_clan_tier', { p_clan: id, p_tier: parseWhole(v.tier, 'Tier'), p_reason: v.reason });
      return 'Tier clan diperbarui';
    });
    if (act === 'xp') return openModal(`XP Clan · ${c.name}`, [
      { name: 'xp', label: `XP clan baru (sekarang ${num(c.xp)})`, type: 'number', min: 0, required: true, value: c.xp },
      REASON
    ], async v => {
      await rpc('admin_set_clan_xp', { p_clan: id, p_xp: parseWhole(v.xp, 'XP'), p_reason: v.reason });
      return 'XP clan diperbarui';
    });
    if (act === 'rename') return openModal(`Ganti nama · ${c.name}`, [
      { name: 'name', label: 'Nama baru (3-24 karakter)', required: true, minlength: 3, maxlength: 24, value: c.name },
      REASON
    ], async v => {
      await rpc('admin_rename_clan', { p_clan: id, p_name: v.name, p_reason: v.reason });
      return 'Nama clan diperbarui';
    });
  }

  /* ---------- Event delegation ---------- */
  document.addEventListener('click', e => {
    const t = e.target;
    if (t.id === 'modal') return closeModal();
    if (t.closest('[data-login]')) return login();
    if (t.closest('[data-logout]')) return logout();
    if (t.closest('[data-close]')) return closeModal();
    const c = t.closest('[data-clan-act]');
    if (c) return clanAction(c.dataset.clanAct, Number(c.dataset.id));
    const u = t.closest('[data-unblock]');
    if (u) return unblockFlow(Number(u.dataset.unblock));
  });

  renderNav();
  window.addEventListener('hashchange', route);
  boot();
})();
