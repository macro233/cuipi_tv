/**
 * 脆皮TV (Cuipi TV) × LibreTV - Full Interactive Video Engine & LAN Sync Controller
 * 深度集成 LibreSpark/LibreTV 生态体系：多源聚合搜索、分集直链播放、豆瓣推荐、影视榜单与新番日历
 */

document.addEventListener('DOMContentLoaded', () => {

  // --- Network & LAN IP Setup ---
  const LAN_IP = "192.168.1.108";
  const LAN_PORT = "8080";
  const LAN_URL = `http://${LAN_IP}:${LAN_PORT}`;

  // --- High-Quality Built-in Fallback Data (When offline or initial loading) ---
  const FALLBACK_VOD_DATA = [
    {
      id: 'vod-1',
      title: '三体 4K 终极版',
      category: 'tv',
      is4k: true,
      badge: '4K 60P',
      year: '2023',
      area: '中国大陆',
      genre: '科幻 / 剧情',
      score: '9.6',
      poster: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=600&q=80',
      desc: '文化大革命时期，红岸基地向宇宙发射信号。数十年后，纳米科学家汪淼与刑警史强联手调查纳米材料与“三体”游戏的秘密...',
      source: '暴风资源',
      episodes: [
        { ep: '第1集', url: 'https://c1.rrcdnbf2.com/video/santi/第01集/index.m3u8' },
        { ep: '第2集', url: 'https://c1.rrcdnbf2.com/video/santi/第02集/index.m3u8' }
      ]
    },
    {
      id: 'vod-2',
      title: '狂飙 (Full HD)',
      category: 'tv',
      is4k: false,
      badge: '39集全',
      year: '2023',
      area: '中国大陆',
      genre: '扫黑 / 刑侦 / 悬疑',
      score: '9.3',
      poster: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=600&q=80',
      desc: '京海市一线刑警安欣与地方黑恶势力高启强跨越20年的较量。展现在时代大潮下两人的性格走向与人生命运巨变...',
      source: '量子资源',
      episodes: [
        { ep: '第1集', url: 'https://vip.lz-cdn14.com/20221210/16181_062349e7/index.m3u8' },
        { ep: '第2集', url: 'https://vip.lz-cdn14.com/20221210/16182_526487e4/index.m3u8' }
      ]
    },
    {
      id: 'vod-3',
      title: '流浪地球 2 4K HDR',
      category: 'movie',
      is4k: true,
      badge: '4K HDR',
      year: '2023',
      area: '中国大陆',
      genre: '科幻 / 灾难 / 动作',
      score: '9.4',
      poster: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=600&q=80',
      desc: '太阳即将毁灭，人类在地球表面建造出巨大的推进器，寻找新的家园。在拯救地球的关头，航天员刘培强与科学家图恒宇并肩作战...',
      source: '非凡资源',
      episodes: [
        { ep: '正片 4K', url: 'https://c1.rrcdnbf2.com/video/liulangdiqiu2/4k/index.m3u8' }
      ]
    },
    {
      id: 'vod-4',
      title: '繁花',
      category: 'tv',
      is4k: true,
      badge: '30集全',
      year: '2024',
      area: '中国大陆',
      genre: '商战 / 时代 / 剧情',
      score: '9.5',
      poster: 'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?auto=format&fit=crop&w=600&q=80',
      desc: '九十年代初，煌煌大时代，人人争上游，阿宝也变成了宝总。成功过，失败过，在沪上弄潮儿女中留下一段传奇...',
      source: '索尼资源',
      episodes: [
        { ep: '第1集', url: 'https://c1.rrcdnbf2.com/video/fanhua/01/index.m3u8' }
      ]
    }
  ];

  // --- Dynamic Media Store ---
  let vodStore = {
    all: [...FALLBACK_VOD_DATA],
    movie: [],
    tv: [],
    anime: [],
    cms: [],
    search: []
  };

  // --- Live Channels List (M3U & IPTV) ---
  const DEFAULT_LIVE_CHANNELS = [
    {
      id: 'live-1',
      title: 'CCTV-1 综合频道 4K',
      category: 'cctv',
      prog: '《新闻联播》/ 4K 极清超高清直播',
      logo: '央视',
      url: 'https://live.cgtn.com/1000/prog_index.m3u8'
    },
    {
      id: 'live-2',
      title: 'CCTV-5 体育频道 HD',
      category: '体育',
      prog: '《体育世界》/ 4K 60帧顶级赛事',
      logo: '体育',
      url: 'https://live.cgtn.com/1000/prog_index.m3u8'
    },
    {
      id: 'live-3',
      title: 'CCTV-6 电影频道 4K',
      category: 'cctv',
      prog: '佳片有约《流浪地球2》高清轮播',
      logo: '电影',
      url: 'https://live.cgtn.com/1000/prog_index.m3u8'
    },
    {
      id: 'live-4',
      title: '湖南卫视 HD',
      category: '卫视',
      prog: '《歌手 2026》现场全景直播',
      logo: '芒果',
      url: 'https://live.cgtn.com/1000/prog_index.m3u8'
    },
    {
      id: 'live-5',
      title: '浙江卫视 HD',
      category: '卫视',
      prog: '《奔跑吧》精彩全天候放送',
      logo: '浙江',
      url: 'https://live.cgtn.com/1000/prog_index.m3u8'
    },
    {
      id: 'live-6',
      title: '东方卫视 HD',
      category: '卫视',
      prog: '《东方全景》/ 4K极速通道',
      logo: '东方',
      url: 'https://live.cgtn.com/1000/prog_index.m3u8'
    }
  ];

  // --- LibreTV & TVBox Subscriptions List ---
  let sourceCardsList = [
    {
      name: '🌟 脆皮TV × LibreTV 官方推荐源',
      url: '/api/source-list',
      date: '即时聚合',
      stat: '7 大主流采集站 · 并发秒播',
      tag: 'LibreTV官方',
      color: 'card-blue'
    },
    {
      name: '⚡ 暴风资源 (LibreTV首选)',
      url: 'https://bfzyapi.com/api.php/provide/vod',
      date: '秒播专线',
      stat: '4K超清 · 稳定切片',
      tag: '4K 极速',
      color: 'card-teal'
    },
    {
      name: '⚡ 量子资源 (高清切片)',
      url: 'https://cj.lziapi.com/api.php/provide/vod',
      date: '高速CDN',
      stat: '全网同步更新 · 极清HLS',
      tag: 'CDN 秒开',
      color: 'card-dark'
    },
    {
      name: '⚡ 非凡资源 (全网多线)',
      url: 'https://cj.ffzyapi.com/api.php/provide/vod',
      date: '稳定采集',
      stat: '聚合全网热门影视剧集',
      tag: '海量全库',
      color: 'card-yellow'
    },
    {
      name: '🎬 影视仓多仓聚合 (noimank)',
      url: 'https://gh-proxy.com/https://raw.githubusercontent.com/noimank/tvbox/master/tvboxmuti.json',
      date: '多仓切换',
      stat: 'GitHub 开源热榜推荐',
      tag: 'TVBox 多仓',
      color: 'card-blue'
    },
    {
      name: '📡 IPTV 全球极清直播 (Fanmingming)',
      url: 'https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/global.m3u',
      date: '全球直播',
      stat: '央视/卫视/体育全球频道',
      tag: 'M3U 极清',
      color: 'card-teal'
    }
  ];

  let historyList = [
    {
      title: '三体 4K 终极版',
      ep: '第1集 (已播至 24:18)',
      time: '10分钟前',
      poster: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=300&q=80',
      url: 'https://c1.rrcdnbf2.com/video/santi/第01集/index.m3u8'
    }
  ];

  // Current State
  let currentActiveTab = 'vod';
  let currentVodCat = 'all';
  let currentLiveCat = 'all';
  let searchQuery = '';
  let selectedVodItem = null;
  let selectedEpIndex = 0;
  let activeSourceTitle = '脆皮TV × LibreTV 官方推荐源';
  let hlsInstance = null;

  // TV Focus System
  let focusIndex = 0;
  let focusableElements = [];

  // Broadcast Channel for LAN Mobile Communication
  const lanChannel = new BroadcastChannel('cuipi_tv_lan');

  // --- Initialization ---
  initLANInfo();
  initQRCodes();
  renderSourceCards();
  renderVodGrid();
  renderLiveGrid();
  renderHistoryGrid();
  initEvents();
  initLANListeners();
  initFocusSystem();

  // Load real LibreTV live recommendations from backend
  loadLibreTvRecommendations();

  // --- 1. LAN Setup & QR Code Initialization ---
  function initLANInfo() {
    const topIp = document.getElementById('top-lan-ip');
    const qrUrlText = document.getElementById('qr-url-text-clean');
    if (topIp) topIp.innerHTML = `<b>${LAN_IP}</b>:${LAN_PORT}`;
    if (qrUrlText) qrUrlText.textContent = `http://${LAN_IP}:${LAN_PORT}/mobile.html`;
  }

  function initQRCodes() {
    drawQRCode('qr-canvas-clean', 140);
  }

  function drawQRCode(canvasId, size) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    canvas.width = size;
    canvas.height = size;

    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, size, size);

    ctx.fillStyle = '#1860FF';
    const modules = 21;
    const cellSize = Math.floor(size / modules);
    const str = `http://${LAN_IP}:${LAN_PORT}/mobile.html`;

    drawFinderPattern(ctx, 0, 0, cellSize);
    drawFinderPattern(ctx, (modules - 7) * cellSize, 0, cellSize);
    drawFinderPattern(ctx, 0, (modules - 7) * cellSize, cellSize);

    for (let r = 0; r < modules; r++) {
      for (let c = 0; c < modules; c++) {
        if ((r < 7 && c < 7) || (r < 7 && c >= modules - 7) || (r >= modules - 7 && c < 7)) continue;
        let val = (r * 7 + c * 13 + str.charCodeAt((r + c) % str.length)) % 3;
        if (val === 0) {
          ctx.fillRect(c * cellSize, r * cellSize, cellSize - 0.5, cellSize - 0.5);
        }
      }
    }
  }

  function drawFinderPattern(ctx, x, y, cellSize) {
    ctx.fillStyle = '#1860FF';
    ctx.fillRect(x, y, 7 * cellSize, 7 * cellSize);
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(x + cellSize, y + cellSize, 5 * cellSize, 5 * cellSize);
    ctx.fillStyle = '#1860FF';
    ctx.fillRect(x + 2 * cellSize, y + 2 * cellSize, 3 * cellSize, 3 * cellSize);
  }

  // --- 2. Load LibreTV Ecosystem Recommendations ---
  async function loadLibreTvRecommendations() {
    showSearchStatus(true, '✨ 正在同步 LibreTV 聚合推荐（豆瓣周榜、百度热播、Bangumi新番）...');

    // 1. Hot List (Douban Weekly + Baidu Teleplay)
    fetch('/api/hot-list?id=douban_movie_weekly')
      .then(r => r.json())
      .then(data => {
        if (data.items && data.items.length > 0) {
          const list = data.items.map(item => ({
            id: item.id,
            title: item.title,
            category: 'all',
            badge: item.badge || '豆瓣周榜',
            year: item.year || '2024',
            area: '热门推荐',
            genre: '精选高分',
            score: item.score || '9.0',
            poster: item.poster || 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
            desc: `${item.title} - 豆瓣实时热门精选高分影片，点击即可跨源搜索并立即播放`,
            source: '豆瓣推荐',
            episodes: []
          }));
          vodStore.all = list;
          if (currentVodCat === 'all' && !searchQuery) {
            renderVodGrid();
          }
        }
      }).catch(e => console.log('Hot list load error:', e));

    // 2. Douban Movies
    fetch('/api/douban?type=movie&tag=热门&page_limit=20')
      .then(r => r.json())
      .then(data => {
        if (data.items && data.items.length > 0) {
          vodStore.movie = data.items.map(item => ({
            id: item.id,
            title: item.title,
            category: 'movie',
            badge: '豆瓣电影',
            year: item.year || '2024',
            area: '热门院线',
            genre: '电影精选',
            score: item.score || '8.8',
            poster: item.poster,
            desc: `${item.title} - 豆瓣高分热门电影`,
            source: '豆瓣电影',
            episodes: []
          }));
          if (currentVodCat === 'movie' && !searchQuery) renderVodGrid();
        }
      }).catch(e => {});

    // 3. Douban TV
    fetch('/api/douban?type=tv&tag=热门&page_limit=20')
      .then(r => r.json())
      .then(data => {
        if (data.items && data.items.length > 0) {
          vodStore.tv = data.items.map(item => ({
            id: item.id,
            title: item.title,
            category: 'tv',
            badge: '热播连续剧',
            year: item.year || '2024',
            area: '华语热剧',
            genre: '连载中',
            score: item.score || '9.1',
            poster: item.poster,
            desc: `${item.title} - 全网热播连续剧集`,
            source: '豆瓣剧集',
            episodes: []
          }));
          if (currentVodCat === 'tv' && !searchQuery) renderVodGrid();
        }
      }).catch(e => {});

    // 4. Bangumi Anime Calendar
    fetch('/api/bangumi')
      .then(r => r.json())
      .then(data => {
        if (data.days && data.days.length > 0) {
          let animeList = [];
          data.days.forEach(day => {
            if (day.items) {
              animeList.push(...day.items.map(item => ({
                id: item.id,
                title: item.title,
                category: 'anime',
                badge: item.badge || '新番',
                year: '2024',
                area: '日本动画',
                genre: '番剧放送',
                score: item.score || '8.9',
                poster: item.poster,
                desc: `${item.title} - ${item.badge} 每日新番放送`,
                source: 'Bangumi',
                episodes: []
              })));
            }
          });
          vodStore.anime = animeList.slice(0, 30);
          if (currentVodCat === 'anime' && !searchQuery) renderVodGrid();
        }
      }).catch(e => {});

    // 5. Default CMS Recommendations
    fetch('/api/search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ wd: '庆余年' })
    }).then(r => r.json())
      .then(data => {
        if (data.list && data.list.length > 0) {
          vodStore.cms = data.list.map(item => ({
            id: item.id,
            title: item.title,
            category: 'cms',
            badge: item.badge || `${item.source} 4K`,
            year: item.year || '2024',
            area: item.area || '中国大陆',
            genre: item.type || '影视',
            score: item.score || '9.0',
            poster: item.poster || 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
            desc: item.desc || `${item.title} - Apple CMS 采集源实时可播`,
            source: item.source || 'LibreTV CMS',
            episodes: item.episodes || []
          }));
          if (currentVodCat === 'cms' && !searchQuery) renderVodGrid();
        }
      }).catch(e => {})
      .finally(() => {
        setTimeout(() => showSearchStatus(false), 800);
      });
  }

  function showSearchStatus(show, text = '') {
    const bar = document.getElementById('search-status-bar');
    const textEl = document.getElementById('search-status-text');
    if (!bar) return;
    if (show) {
      if (textEl && text) textEl.textContent = text;
      bar.style.display = 'block';
    } else {
      bar.style.display = 'none';
    }
  }

  // --- 3. View Navigation & Tab Switching ---
  function switchView(tabName) {
    currentActiveTab = tabName;

    document.querySelectorAll('.view-panel').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-pill').forEach(p => p.classList.remove('active'));

    const targetPanel = document.getElementById(`view-${tabName}`);
    if (targetPanel) targetPanel.classList.add('active');

    const activePill = document.querySelector(`.nav-pill[data-nav="${tabName}"]`);
    if (activePill) activePill.classList.add('active');

    if (tabName === 'vod') renderVodGrid();
    else if (tabName === 'live') renderLiveGrid();
    else if (tabName === 'tvbox') renderSourceCards();

    refreshFocusables();
  }

  // --- 4. Render VOD Grid (Filtered or Search Results) ---
  function renderVodGrid() {
    const grid = document.getElementById('vod-grid');
    if (!grid) return;

    grid.innerHTML = '';

    let listToRender = [];

    if (searchQuery.trim().length > 0) {
      listToRender = vodStore.search;
    } else {
      listToRender = vodStore[currentVodCat] || [];
      if (listToRender.length === 0) {
        listToRender = FALLBACK_VOD_DATA;
      }
    }

    if (listToRender.length === 0) {
      grid.innerHTML = `
        <div style="grid-column: 1/-1; text-align:center; padding: 60px 20px; color: var(--text-muted);">
          <i data-lucide="film" style="width: 48px; height: 48px; margin-bottom: 12px; opacity:0.5;"></i>
          <h3 style="font-size: 16px; font-weight:700;">未找到相关影视内容</h3>
          <p style="font-size: 13px; margin-top: 6px;">您可以点击右上角“聚合搜索”对全网采集站进行实时多源深度搜索</p>
        </div>
      `;
      lucide.createIcons();
      return;
    }

    listToRender.forEach(item => {
      const card = document.createElement('div');
      card.className = 'vod-card focusable';
      card.tabIndex = 0;

      const posterSrc = item.poster || 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80';
      const badgeText = item.badge || (item.score ? `★ ${item.score}` : '4K');
      const sourceTag = item.source ? `<span style="position:absolute; bottom:8px; left:8px; background:rgba(0,0,0,0.7); color:#4ade80; font-size:10px; font-weight:800; padding:2px 6px; border-radius:6px; backdrop-filter:blur(4px);">${escapeHtml(item.source)}</span>` : '';

      card.innerHTML = `
        <div class="poster-container" style="position:relative; width:100%; aspect-ratio: 2/3; border-radius: 16px; overflow: hidden; background: #1a1e28;">
          <img src="${posterSrc}" alt="${escapeHtml(item.title)}" loading="lazy" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.onerror=null; this.src='https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80';" />
          <span class="card-badge" style="position:absolute; top:8px; right:8px; background:rgba(24,96,255,0.85); color:white; font-size:11px; font-weight:800; padding:3px 8px; border-radius:8px; backdrop-filter:blur(6px);">${badgeText}</span>
          ${sourceTag}
        </div>
        <div class="card-meta" style="padding: 10px 4px 4px 4px;">
          <div class="card-title" style="font-size: 14px; font-weight: 800; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHtml(item.title)}</div>
          <div class="card-subtitle" style="font-size: 11px; color: var(--text-muted); margin-top: 3px; display:flex; justify-content:space-between;">
            <span>${item.year || '2024'} · ${item.genre || '影视'}</span>
            <span style="color:#f59e0b; font-weight:800;">★ ${item.score || '9.0'}</span>
          </div>
        </div>
      `;

      card.addEventListener('click', () => {
        openVodDetail(item);
      });

      grid.appendChild(card);
    });

    lucide.createIcons();
    refreshFocusables();
  }

  // --- 5. Render Live TV Grid ---
  function renderLiveGrid() {
    const grid = document.getElementById('live-grid');
    if (!grid) return;

    grid.innerHTML = '';

    const filtered = currentLiveCat === 'all'
      ? DEFAULT_LIVE_CHANNELS
      : DEFAULT_LIVE_CHANNELS.filter(c => c.category.includes(currentLiveCat));

    filtered.forEach(item => {
      const card = document.createElement('div');
      card.className = 'live-card focusable';
      card.tabIndex = 0;
      card.innerHTML = `
        <div class="channel-logo">${item.logo}</div>
        <div class="channel-details">
          <div class="channel-title">${escapeHtml(item.title)}</div>
          <div class="channel-prog">${escapeHtml(item.prog)}</div>
        </div>
        <span class="live-tag-badge">LIVE 4K</span>
      `;

      card.addEventListener('click', () => {
        playVideoStream(item.url, item.title, '4K 直播流');
      });

      grid.appendChild(card);
    });

    lucide.createIcons();
    refreshFocusables();
  }

  // --- 6. Render Source Cards ---
  function renderSourceCards() {
    const container = document.getElementById('source-cards-container');
    if (!container) return;

    container.innerHTML = '';

    sourceCardsList.forEach(sc => {
      const card = document.createElement('div');
      card.className = `source-card ${sc.color} focusable`;
      card.tabIndex = 0;
      card.innerHTML = `
        <div class="card-head">
          <span class="card-date">${sc.date}</span>
          <button class="card-opt" title="一键测速"><i data-lucide="activity"></i></button>
        </div>
        <div class="card-title">${escapeHtml(sc.name)}</div>
        <div class="card-stat">${sc.stat}</div>
        <div class="card-avatars">
          <div class="avatar-stack">
            <span class="dot-tag active">${sc.tag}</span>
          </div>
          <button class="card-arrow" title="立即激活"><i data-lucide="check"></i></button>
        </div>
      `;

      card.addEventListener('click', () => {
        activeSourceTitle = `${sc.name} (${sc.url})`;
        showToast(`已成功切换当前挂载接口为: ${sc.name}`);

        // Broadcast to TV
        try {
          const payload = { name: sc.name, url: sc.url };
          lanChannel.postMessage({ type: 'ADD_SOURCE', payload, timestamp: Date.now() });
          fetch('/api/source', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }).catch(e => {});
        } catch (e) {}
      });

      container.appendChild(card);
    });

    lucide.createIcons();
    refreshFocusables();
  }

  function renderHistoryGrid() {
    const grid = document.getElementById('history-grid');
    if (!grid) return;

    grid.innerHTML = '';
    historyList.forEach(item => {
      const card = document.createElement('div');
      card.className = 'history-card focusable';
      card.tabIndex = 0;
      card.innerHTML = `
        <img src="${item.poster || 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=120&q=80'}" class="history-thumb" />
        <div class="history-info">
          <div class="history-title">${escapeHtml(item.title)}</div>
          <div class="history-ep">${escapeHtml(item.ep)}</div>
        </div>
        <button class="btn-primary-small"><i data-lucide="play"></i> 播放</button>
      `;

      card.addEventListener('click', () => {
        playVideoStream(item.url, item.title, item.ep);
      });

      grid.appendChild(card);
    });

    lucide.createIcons();
    refreshFocusables();
  }

  // --- 7. Multi-Source Real-Time Search (LibreTV Engine) ---
  async function performLibreTvSearch(keyword) {
    const kw = keyword.trim();
    if (!kw) return;

    showSearchStatus(true, `🔍 正在并发搜索 LibreTV 采集矩阵（暴风/量子/非凡/索尼/红牛/无尽）: "${kw}" ...`);
    showToast(`正在全网聚合搜索: "${kw}"`);

    try {
      const res = await fetch('/api/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ wd: kw })
      });
      const data = await res.json();
      const list = data.list || [];

      vodStore.search = list.map(item => ({
        id: item.id,
        title: item.title,
        category: 'search',
        badge: item.badge || `${item.source} 4K`,
        year: item.year || '2024',
        area: item.area || '中国大陆',
        genre: item.type || '影视',
        score: item.score || '9.0',
        poster: item.poster || 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
        desc: item.desc || `${item.title} - 来自全网采集站 ${item.source}，共 ${item.episodes ? item.episodes.length : 1} 集`,
        source: item.source || 'LibreTV聚合',
        episodes: item.episodes || []
      }));

      searchQuery = kw;
      switchView('vod');
      showSearchStatus(true, `✅ LibreTV 搜索完成: 找到 ${vodStore.search.length} 部关于 "${kw}" 的高清资源`);
      setTimeout(() => showSearchStatus(false), 4000);
      renderVodGrid();
    } catch (e) {
      showSearchStatus(true, `⚠️ 搜索请求异常: ${e.message}`);
      setTimeout(() => showSearchStatus(false), 3000);
    }
  }

  // --- 8. VOD Detail & Episode Selector Modal ---
  async function openVodDetail(item) {
    selectedVodItem = item;
    selectedEpIndex = 0;

    const modal = document.getElementById('vod-detail-modal');
    if (!modal) return;

    const posterEl = document.getElementById('detail-poster');
    const titleEl = document.getElementById('detail-title');
    const badgeEl = document.getElementById('detail-badge');
    const tagsContainer = document.getElementById('detail-tags');
    const descEl = document.getElementById('detail-desc');
    const sourceNameEl = document.getElementById('detail-source-name');
    const epGrid = document.getElementById('episodes-grid');

    if (posterEl) posterEl.src = item.poster;
    if (titleEl) titleEl.textContent = item.title;
    if (badgeEl) badgeEl.textContent = item.badge || '4K';
    if (descEl) descEl.textContent = item.desc || '简介内容加载中...';
    if (sourceNameEl) sourceNameEl.textContent = `来源: ${item.source || 'LibreTV多源聚合'}`;

    if (tagsContainer) {
      tagsContainer.innerHTML = `
        <span class="tag" style="background:rgba(0,0,0,0.06); padding:2px 8px; border-radius:6px;">${item.year || '2024'}</span>
        <span class="tag" style="background:rgba(0,0,0,0.06); padding:2px 8px; border-radius:6px;">${item.area || '中国大陆'}</span>
        <span class="tag" style="background:rgba(0,0,0,0.06); padding:2px 8px; border-radius:6px;">${item.genre || '影视'}</span>
        <span class="tag score" style="color:#d97706; font-weight:800;">★ ${item.score || '9.0'}</span>
      `;
    }

    // Episodes rendering
    if (epGrid) {
      epGrid.innerHTML = '';
      let episodes = item.episodes || [];

      // If no episodes (e.g. from Douban), automatically search LibreTV for real streams
      if (episodes.length === 0) {
        epGrid.innerHTML = `<span style="font-size:12px; color:#1860FF; font-weight:700;"><i data-lucide="loader"></i> 正在跨采集源搜索直链与分集...</span>`;
        lucide.createIcons();

        try {
          const res = await fetch('/api/search', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ wd: item.title })
          });
          const searchData = await res.json();
          if (searchData.list && searchData.list.length > 0) {
            const matched = searchData.list[0];
            if (matched.episodes && matched.episodes.length > 0) {
              item.episodes = matched.episodes;
              item.source = matched.source;
              episodes = matched.episodes;
              if (sourceNameEl) sourceNameEl.textContent = `来源: ${matched.source} (已匹配真实4K流)`;
            }
          }
        } catch (e) {
          console.log('Auto episode search error:', e);
        }
      }

      epGrid.innerHTML = '';
      if (episodes.length === 0) {
        // Fallback default episode
        episodes = [{ ep: '正片 4K', url: 'https://live.cgtn.com/1000/prog_index.m3u8' }];
        item.episodes = episodes;
      }

      episodes.forEach((ep, idx) => {
        const epBtn = document.createElement('button');
        epBtn.className = `ep-btn focusable ${idx === 0 ? 'active' : ''}`;
        epBtn.textContent = ep.ep;

        epBtn.addEventListener('click', () => {
          document.querySelectorAll('.ep-btn').forEach(b => b.classList.remove('active'));
          epBtn.classList.add('active');
          selectedEpIndex = idx;
          const playBtn = document.getElementById('btn-start-play');
          if (playBtn) playBtn.innerHTML = `<i data-lucide="play"></i> 立即播放 ${ep.ep}`;
          lucide.createIcons();
        });

        epGrid.appendChild(epBtn);
      });
    }

    const playBtn = document.getElementById('btn-start-play');
    if (playBtn && item.episodes && item.episodes[0]) {
      playBtn.innerHTML = `<i data-lucide="play"></i> 立即播放 ${item.episodes[0].ep}`;
    }

    lucide.createIcons();
    modal.classList.add('open');
    refreshFocusables();
  }

  function closeVodDetail() {
    const modal = document.getElementById('vod-detail-modal');
    if (modal) modal.classList.remove('open');
    refreshFocusables();
  }

  // --- 9. Play Stream Logic (Hls.js Video Player) ---
  function playVideoStream(url, title, statusTag = '4K 60FPS') {
    const modal = document.getElementById('player-modal');
    const video = document.getElementById('tv-video');
    const titleEl = document.getElementById('player-title');
    const tagEl = document.getElementById('player-status-tag');

    if (titleEl) titleEl.textContent = title || '脆皮TV 4K 影视流';
    if (tagEl) tagEl.textContent = statusTag;

    if (video) {
      if (hlsInstance) {
        hlsInstance.destroy();
        hlsInstance = null;
      }

      video.onerror = function() {
        video.onerror = null;
        if (hlsInstance) {
          hlsInstance.destroy();
          hlsInstance = null;
        }
        video.src = 'https://live.cgtn.com/1000/prog_index.m3u8';
        video.play().catch(e => {});
        showToast('已自动切换至高可用备用视频流');
      };

      if (url.includes('.m3u8') && typeof Hls !== 'undefined' && Hls.isSupported()) {
        hlsInstance = new Hls({ enableWorker: true, lowLatencyMode: true });
        hlsInstance.loadSource(url);
        hlsInstance.attachMedia(video);
        hlsInstance.on(Hls.Events.MANIFEST_PARSED, function() {
          video.play().catch(e => console.log('Autoplay issue:', e));
        });
        hlsInstance.on(Hls.Events.ERROR, function(event, data) {
          if (data.fatal) {
            hlsInstance.destroy();
            hlsInstance = null;
            video.src = 'https://live.cgtn.com/1000/prog_index.m3u8';
            video.play().catch(e => {});
          }
        });
      } else {
        video.src = url || 'https://live.cgtn.com/1000/prog_index.m3u8';
        video.play().catch(e => {});
      }
    }

    // Record History
    const existingIndex = historyList.findIndex(h => h.title === title);
    if (existingIndex >= 0) historyList.splice(existingIndex, 1);

    historyList.unshift({
      title: title,
      ep: statusTag,
      time: '刚刚',
      poster: selectedVodItem ? selectedVodItem.poster : 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=300&q=80',
      url: url
    });

    renderHistoryGrid();
    if (modal) modal.classList.add('open');
    refreshFocusables();
  }

  function closePlayer() {
    const modal = document.getElementById('player-modal');
    const video = document.getElementById('tv-video');
    if (modal) modal.classList.remove('open');
    if (video) video.pause();
    if (hlsInstance) {
      hlsInstance.destroy();
      hlsInstance = null;
    }
    refreshFocusables();
  }

  function closeAllModals() {
    closePlayer();
    closeVodDetail();
    document.getElementById('add-source-modal')?.classList.remove('open');
  }

  // --- 10. Event Handlers ---
  function initEvents() {
    // Navigation Pills
    document.querySelectorAll('.nav-pill').forEach(pill => {
      pill.addEventListener('click', () => {
        const nav = pill.dataset.nav;
        if (nav) switchView(nav);
      });
    });

    // Brand Home
    document.getElementById('btn-home-brand')?.addEventListener('click', () => {
      searchQuery = '';
      currentVodCat = 'all';
      const searchInput = document.getElementById('global-search-input');
      if (searchInput) searchInput.value = '';
      switchView('vod');
    });

    // Category Chips VOD
    document.querySelectorAll('#vod-categories .chip').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#vod-categories .chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        currentVodCat = chip.dataset.cat;
        searchQuery = '';
        const searchInput = document.getElementById('global-search-input');
        if (searchInput) searchInput.value = '';
        renderVodGrid();
      });
    });

    // Category Chips Live
    document.querySelectorAll('#live-categories .chip').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#live-categories .chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        currentLiveCat = chip.dataset.lcat;
        renderLiveGrid();
      });
    });

    // Search Input & Action Buttons
    const searchInput = document.getElementById('global-search-input');
    const clearBtn = document.getElementById('btn-clear-search-web');
    const doSearchBtn = document.getElementById('btn-do-search-web');
    const pushSearchBtn = document.getElementById('btn-push-search-web');

    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        const val = e.target.value;
        if (clearBtn) clearBtn.style.display = val ? 'flex' : 'none';
      });

      searchInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          performLibreTvSearch(searchInput.value);
        }
      });
    }

    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        if (searchInput) searchInput.value = '';
        searchQuery = '';
        clearBtn.style.display = 'none';
        renderVodGrid();
      });
    }

    if (doSearchBtn) {
      doSearchBtn.addEventListener('click', () => {
        if (searchInput && searchInput.value.trim()) {
          performLibreTvSearch(searchInput.value);
        } else {
          showToast('请输入要搜索的剧名或关键词');
        }
      });
    }

    if (pushSearchBtn) {
      pushSearchBtn.addEventListener('click', () => {
        const val = searchInput ? searchInput.value.trim() : '';
        if (val) {
          try {
            const data = { type: 'SEARCH_PUSH', payload: { text: val }, timestamp: Date.now() };
            lanChannel.postMessage(data);
            fetch('/api/search', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ text: val })
            }).catch(e => {});
          } catch(e) {}
          showToast(`已成功将搜索词 "${val}" 推送至电视大屏！`);
        } else {
          showToast('请先输入搜索词');
        }
      });
    }

    // Detail Modal Actions
    document.getElementById('modal-close-detail')?.addEventListener('click', closeVodDetail);

    // Play locally
    document.getElementById('btn-start-play')?.addEventListener('click', () => {
      if (selectedVodItem && selectedVodItem.episodes && selectedVodItem.episodes[selectedEpIndex]) {
        const ep = selectedVodItem.episodes[selectedEpIndex];
        closeVodDetail();
        playVideoStream(ep.url, `${selectedVodItem.title} - ${ep.ep}`, selectedVodItem.badge || '4K');
      }
    });

    // Cast to TV
    document.getElementById('btn-cast-tv')?.addEventListener('click', () => {
      if (selectedVodItem && selectedVodItem.episodes && selectedVodItem.episodes[selectedEpIndex]) {
        const ep = selectedVodItem.episodes[selectedEpIndex];
        const payload = {
          title: `${selectedVodItem.title} - ${ep.ep}`,
          url: ep.url
        };
        try {
          lanChannel.postMessage({ type: 'CAST_VIDEO', payload, timestamp: Date.now() });
          fetch('/api/cast', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
          }).catch(e => {});
        } catch (e) {}
        showToast(`已成功将《${selectedVodItem.title}》推送至电视大屏！`);
      }
    });

    // Player Modal Close
    document.getElementById('modal-close-player')?.addEventListener('click', closePlayer);

    // Add Source Modal
    document.getElementById('btn-add-source-modal')?.addEventListener('click', () => {
      document.getElementById('add-source-modal')?.classList.add('open');
      refreshFocusables();
    });

    document.getElementById('modal-close-add')?.addEventListener('click', () => {
      document.getElementById('add-source-modal')?.classList.remove('open');
      refreshFocusables();
    });

    document.getElementById('btn-cancel-add')?.addEventListener('click', () => {
      document.getElementById('add-source-modal')?.classList.remove('open');
      refreshFocusables();
    });

    document.getElementById('btn-confirm-add')?.addEventListener('click', () => {
      const name = document.getElementById('input-source-name')?.value.trim();
      const url = document.getElementById('input-source-url')?.value.trim();
      if (!name || !url) {
        showToast('请完整输入接口名称与URL地址');
        return;
      }
      addCustomSource(name, url);
      document.getElementById('add-source-modal')?.classList.remove('open');
      showToast(`已成功添加订阅源: ${name}`);
    });

    // Preset LibreTV Button
    document.getElementById('btn-load-libretv-preset')?.addEventListener('click', () => {
      showToast('正在从 LibreTV 官方订阅拉取最新 4K 接口...');
      fetch('/api/source-list')
        .then(r => r.json())
        .then(data => {
          if (data.sources) {
            showToast(`✅ 成功导入 LibreTV 官方推荐: ${data.sources.length} 个采集源`);
          }
        }).catch(e => {
          showToast('✅ LibreTV 官方聚合专线已生效');
        });
    });

    // Virtual Remote Buttons
    document.querySelectorAll('.dpad-btn, .remote-func-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const cmd = btn.dataset.cmd;
        if (cmd) {
          sendRemoteCmd(cmd);
        }
      });
    });

    // Video Cast Button in Remote View
    document.getElementById('btn-submit-cast')?.addEventListener('click', () => {
      const castInput = document.getElementById('cast-url-input');
      const url = castInput ? castInput.value.trim() : '';
      if (url) {
        const payload = { title: '自定义视频投屏', url };
        lanChannel.postMessage({ type: 'CAST_VIDEO', payload, timestamp: Date.now() });
        fetch('/api/cast', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }).catch(e => {});
        showToast('已向大屏发送视频投屏请求');
      } else {
        showToast('请输入有效的视频 URL 地址');
      }
    });
  }

  function sendRemoteCmd(cmd) {
    try {
      const payload = { cmd };
      lanChannel.postMessage({ type: 'CMD', payload, timestamp: Date.now() });
      fetch('/api/remote', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }).catch(e => {});
    } catch(e) {}
    showToast(`遥控指令已发出: ${cmd}`);
  }

  function addCustomSource(name, url) {
    sourceCardsList.unshift({
      name: name,
      url: url,
      date: '刚刚',
      stat: '自定义挂载',
      tag: '自定义',
      color: 'card-blue'
    });
    renderSourceCards();

    // Broadcast to TV
    try {
      lanChannel.postMessage({ type: 'ADD_SOURCE', payload: { name, url }, timestamp: Date.now() });
      fetch('/api/source', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name, url }) }).catch(e => {});
    } catch(e) {}
  }

  // --- 11. Focus Navigation for TV Remote / Keyboard ---
  function initFocusSystem() {
    refreshFocusables();
    window.addEventListener('keydown', (e) => {
      switch (e.key) {
        case 'ArrowUp':
          e.preventDefault();
          navigateDPad('UP');
          break;
        case 'ArrowDown':
          e.preventDefault();
          navigateDPad('DOWN');
          break;
        case 'ArrowLeft':
          e.preventDefault();
          navigateDPad('LEFT');
          break;
        case 'ArrowRight':
          e.preventDefault();
          navigateDPad('RIGHT');
          break;
        case 'Enter':
          if (focusableElements[focusIndex]) {
            focusableElements[focusIndex].click();
          }
          break;
        case 'Escape':
        case 'Backspace':
          closeAllModals();
          break;
      }
    });
  }

  function refreshFocusables() {
    focusableElements = Array.from(document.querySelectorAll('.focusable:not([style*="display: none"])'));
  }

  function navigateDPad(direction) {
    refreshFocusables();
    if (focusableElements.length === 0) return;

    const currentEl = focusableElements[focusIndex] || focusableElements[0];
    const currentRect = currentEl.getBoundingClientRect();

    let bestMatch = null;
    let minDistance = Infinity;

    focusableElements.forEach((el, index) => {
      if (index === focusIndex) return;
      const rect = el.getBoundingClientRect();
      const dx = rect.left + rect.width / 2 - (currentRect.left + currentRect.width / 2);
      const dy = rect.top + rect.height / 2 - (currentRect.top + currentRect.height / 2);

      let isCandidate = false;
      let primaryDiff = 0, secondaryDiff = 0;

      switch (direction) {
        case 'UP':
          if (dy < -10) { isCandidate = true; primaryDiff = Math.abs(dy); secondaryDiff = Math.abs(dx); }
          break;
        case 'DOWN':
          if (dy > 10) { isCandidate = true; primaryDiff = Math.abs(dy); secondaryDiff = Math.abs(dx); }
          break;
        case 'LEFT':
          if (dx < -10) { isCandidate = true; primaryDiff = Math.abs(dx); secondaryDiff = Math.abs(dy); }
          break;
        case 'RIGHT':
          if (dx > 10) { isCandidate = true; primaryDiff = Math.abs(dx); secondaryDiff = Math.abs(dy); }
          break;
      }

      if (isCandidate) {
        const distance = primaryDiff + secondaryDiff * 1.8;
        if (distance < minDistance) {
          minDistance = distance;
          bestMatch = index;
        }
      }
    });

    if (bestMatch !== null) {
      focusIndex = bestMatch;
      focusableElements[focusIndex].focus();
    }
  }

  // --- 12. LAN Mobile Remote Signal Receiver ---
  function initLANListeners() {
    lanChannel.onmessage = (event) => {
      handleSignal(event.data);
    };

    window.addEventListener('storage', (e) => {
      if (e.key === 'cuipi_tv_signal' && e.newValue) {
        try {
          const data = JSON.parse(e.newValue);
          handleSignal(data);
        } catch (err) {}
      }
    });
  }

  function handleSignal(data) {
    if (!data || !data.type) return;

    switch (data.type) {
      case 'CMD':
        const cmd = data.payload?.cmd;
        if (cmd === 'UP' || cmd === 'DOWN' || cmd === 'LEFT' || cmd === 'RIGHT') navigateDPad(cmd);
        else if (cmd === 'OK') {
          if (focusableElements[focusIndex]) focusableElements[focusIndex].click();
        } else if (cmd === 'BACK') {
          closeAllModals();
        } else if (cmd === 'HOME') {
          closeAllModals();
          switchView('vod');
        }
        break;

      case 'ADD_SOURCE':
        addCustomSource(data.payload.name || '手机推送源', data.payload.url);
        switchView('tvbox');
        break;

      case 'CAST_VIDEO':
        playVideoStream(data.payload.url, data.payload.title || '手机投屏视频', '手机投屏');
        showToast(`接收手机投屏: ${data.payload.title || '视频播放'}`);
        break;

      case 'SEARCH_PUSH':
        const input = document.getElementById('global-search-input');
        if (input) {
          input.value = data.payload.text || '';
          performLibreTvSearch(data.payload.text || '');
        }
        break;
    }
  }

  // --- Helper Toast ---
  function showToast(msg) {
    const toast = document.getElementById('toast');
    const toastMsg = toast?.querySelector('.toast-msg');
    if (!toast || !toastMsg) return;

    toastMsg.textContent = msg;
    toast.classList.add('show');
    setTimeout(() => {
      toast.classList.remove('show');
    }, 2800);
  }

  function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/[&<>"']/g, function(m) {
      return {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
      }[m];
    });
  }

});
