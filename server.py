import http.server
import socketserver
import os
import time
import threading
import json
import urllib.request
import urllib.parse
import re
from concurrent.futures import ThreadPoolExecutor, as_completed

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

# Live Reload Event Clients
sse_clients = []
last_mtime = {}

# Simple in-memory cache
api_cache = {}
CACHE_TTL = 300  # 5 minutes

def get_cached(key):
    if key in api_cache:
        data, exp = api_cache[key]
        if time.time() < exp:
            return data
        del api_cache[key]
    return None

def set_cached(key, data, ttl=CACHE_TTL):
    api_cache[key] = (data, time.time() + ttl)

# Default Apple CMS sources from LibreTV ecosystem
DEFAULT_CMS_SOURCES = [
    {"name": "红牛资源", "url": "https://www.hongniuzy2.com/api.php/provide/vod"},
    {"name": "暴风资源", "url": "https://bfzyapi.com/api.php/provide/vod"},
    {"name": "量子资源", "url": "https://cj.lziapi.com/api.php/provide/vod"},
    {"name": "非凡资源", "url": "https://cj.ffzyapi.com/api.php/provide/vod"},
    {"name": "索尼资源", "url": "https://suoniapi.com/api.php/provide/vod"},
    {"name": "无尽资源", "url": "https://api.wujinapi.me/api.php/provide/vod"},
]

# Curated high-star GitHub TVBox & LibreTV Repositories
CURATED_GITHUB_SOURCES = [
    {
        "name": "肥猫影视仓 (gaotianliuyun/gao)",
        "author": "gaotianliuyun",
        "stars": 6800,
        "repo": "gaotianliuyun/gao",
        "rawUrl": "https://raw.githubusercontent.com/gaotianliuyun/gao/master/0821.json",
        "desc": "全网最热门TVBox源之一，86个高质量站点，含超清秒播切片与独家线路",
        "tags": ["热门", "秒播", "影视仓", "4K", "肥猫"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "影视仓多仓聚合 (noimank/tvbox)",
        "author": "noimank",
        "stars": 5400,
        "repo": "noimank/tvbox",
        "rawUrl": "https://raw.githubusercontent.com/noimank/tvbox/master/tvboxmuti.json",
        "desc": "noimank 长期维护多仓源，汇聚肥猫、饭太硬、巧技等多家仓库，一键切换",
        "tags": ["多仓聚合", "推荐", "多线路", "稳定", "影视仓"],
        "isLive": False,
        "isMulti": True
    },
    {
        "name": "饭太硬主线仓 (fantaiying/fty)",
        "author": "fantaiying",
        "stars": 4900,
        "repo": "fantaiying/fty",
        "rawUrl": "https://raw.githubusercontent.com/fantaiying/fty/main/fty.json",
        "desc": "更新频繁、超高稳定性、自带全套影视爬虫与超清解析引擎",
        "tags": ["饭太硬", "高画质", "秒播", "热门"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "IPTV全球高清直播 (fanmingming/live)",
        "author": "fanmingming",
        "stars": 28600,
        "repo": "fanmingming/live",
        "rawUrl": "https://raw.githubusercontent.com/fanmingming/live/main/tv/m3u/global.m3u",
        "desc": "全球高星 IPTV 直播流项目，含央视全套4K/8K、各省卫视、港澳台与国际频道",
        "tags": ["直播", "CCTV", "4K", "卫视", "IPTV", "央视"],
        "isLive": True,
        "isMulti": False
    },
    {
        "name": "巧技多线路仓库 (qiaojiujiu/TVBox)",
        "author": "qiaojiujiu",
        "stars": 3200,
        "repo": "qiaojiujiu/TVBox",
        "rawUrl": "https://raw.githubusercontent.com/qiaojiujiu/TVBox/main/qq.json",
        "desc": "巧技团队出品，多条高速节点容灾备份，涵盖各大主流视频站点",
        "tags": ["巧技", "备用多线", "稳定"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "毒盒综合仓库 (DHJ1222/TVBox)",
        "author": "DHJ1222",
        "stars": 3100,
        "repo": "DHJ1222/TVBox",
        "rawUrl": "https://raw.githubusercontent.com/DHJ1222/TVBox/main/duhe.json",
        "desc": "经典毒盒接口，精简高速，画质优选，无冗余失效接口",
        "tags": ["毒盒", "精简", "高速"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "PG高清影视仓库 (PizGY/GY_TVBox)",
        "author": "PizGY",
        "stars": 2900,
        "repo": "PizGY/GY_TVBox",
        "rawUrl": "https://raw.githubusercontent.com/PizGY/GY_TVBox/main/gy.json",
        "desc": "高清影视资源为主，注重蓝光画质与杜比音轨体验",
        "tags": ["蓝光", "杜比", "PG"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "星空聚合仓库 (xiaochuanmm/TVBox-zy)",
        "author": "xiaochuanmm",
        "stars": 2400,
        "repo": "xiaochuanmm/TVBox-zy",
        "rawUrl": "https://raw.githubusercontent.com/xiaochuanmm/TVBox-zy/main/sc.json",
        "desc": "整合大量二次元新番、热播综艺与纪录片特色线路",
        "tags": ["动漫", "纪录片", "星空"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "猫影视蜘蛛源 (FongMi/CatVodSpider)",
        "author": "FongMi",
        "stars": 8200,
        "repo": "FongMi/CatVodSpider",
        "rawUrl": "https://raw.githubusercontent.com/FongMi/CatVodSpider/main/json/config.json",
        "desc": "FongMi 猫影视核心蜘蛛源，支持最新爬虫与多源并发提取",
        "tags": ["猫影视", "蜘蛛爬虫", "极客", "俊于"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "YYDS 影视仓源 (yydsys/yydsys.github.io)",
        "author": "yydsys",
        "stars": 3700,
        "repo": "yydsys/yydsys.github.io",
        "rawUrl": "https://raw.githubusercontent.com/yydsys/yydsys.github.io/main/yydsys/yydsys.json",
        "desc": "老牌稳定订阅，海量采集站点整合，支持搜索与电视直播",
        "tags": ["YYDS", "全功能", "直播"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "月光宝盒仓库 (guot55/YGBH)",
        "author": "guot55",
        "stars": 2600,
        "repo": "guot55/YGBH",
        "rawUrl": "https://raw.githubusercontent.com/guot55/YGBH/main/box.json",
        "desc": "月光宝盒尊享版线路，纯净无广，分类详尽",
        "tags": ["月光宝盒", "纯净", "4K"],
        "isLive": False,
        "isMulti": False
    },
    {
        "name": "IPTV 央视卫视 IPv6 直播 (ssili126/tv)",
        "author": "ssili126",
        "stars": 4100,
        "repo": "ssili126/tv",
        "rawUrl": "https://raw.githubusercontent.com/ssili126/tv/main/tv.m3u",
        "desc": "全网超低延迟 IPv6 4K 电视直播源，秒开秒换台",
        "tags": ["直播", "IPv6", "超清", "央视"],
        "isLive": True,
        "isMulti": False
    }
]

def search_github_sources(keyword=""):
    """
    搜索 GitHub TVBox 与 LibreTV 源：
    1. 优先在精选高星 GitHub 源库中做模糊与标签匹配；
    2. 若关键词有具体仓库名或非空，同时请求 GitHub API 进行实时探索；
    3. 自动注入 gh-proxy.com 国内加速镜像地址。
    """
    clean_kw = keyword.strip().lower()
    results = []
    seen_urls = set()

    def make_item(item):
        raw = item.get("rawUrl", "")
        mirror = f"https://gh-proxy.com/{raw}" if "raw.githubusercontent.com" in raw else raw
        return {
            "name": item.get("name", "GitHub 源"),
            "author": item.get("author", "GitHub 开发者"),
            "stars": item.get("stars", 100),
            "repo": item.get("repo", ""),
            "rawUrl": raw,
            "mirrorUrl": mirror,
            "url": mirror,
            "desc": item.get("desc", ""),
            "tags": item.get("tags", ["TVBox", "GitHub"]),
            "isLive": item.get("isLive", False),
            "isMulti": item.get("isMulti", False)
        }

    # 1. 匹配精选库
    for item in CURATED_GITHUB_SOURCES:
        if not clean_kw:
            results.append(make_item(item))
            seen_urls.add(item["rawUrl"])
            continue
        text = f"{item['name']} {item['author']} {item['desc']} {' '.join(item['tags'])} {item['repo']}".lower()
        if clean_kw in text:
            results.append(make_item(item))
            seen_urls.add(item["rawUrl"])

    # 2. 调用 GitHub API 实时探索
    if clean_kw and clean_kw not in ["all", "热门", "推荐"]:
        try:
            gh_query = f"{urllib.parse.quote(clean_kw)}+tvbox"
            req = urllib.request.Request(
                f"https://api.github.com/search/repositories?q={gh_query}&sort=stars&order=desc&per_page=10",
                headers={
                    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) CuipiTV/1.0",
                    "Accept": "application/vnd.github.v3+json"
                }
            )
            with urllib.request.urlopen(req, timeout=4) as r:
                gh_data = json.loads(r.read().decode('utf-8'))
                for repo in gh_data.get("items", []):
                    full_name = repo.get("full_name", "")
                    default_branch = repo.get("default_branch", "main")
                    raw_candidate = f"https://raw.githubusercontent.com/{full_name}/{default_branch}/{repo.get('name')}.json"
                    if raw_candidate not in seen_urls:
                        seen_urls.add(raw_candidate)
                        desc = repo.get("description") or f"GitHub 开源仓库 {full_name}"
                        results.append(make_item({
                            "name": f"📦 {full_name}",
                            "author": repo.get("owner", {}).get("login", ""),
                            "stars": repo.get("stargazers_count", 0),
                            "repo": full_name,
                            "rawUrl": raw_candidate,
                            "desc": desc,
                            "tags": ["GitHub实时", "TVBox"],
                            "isLive": "live" in full_name.lower() or "iptv" in full_name.lower(),
                            "isMulti": False
                        }))
        except Exception as e:
            print(f"[GitHub Search] API exploration skipped: {e}")

    results.sort(key=lambda x: x.get("stars", 0), reverse=True)
    return results

def check_file_changes():
    global last_mtime
    watch_files = ['index.html', 'app.js', 'style.css', 'mobile.html', 'remote.html', 'libretv_sources.json']
    while True:
        time.sleep(0.5)
        changed = False
        for f in watch_files:
            p = os.path.join(DIRECTORY, f)
            if os.path.exists(p):
                mtime = os.path.getmtime(p)
                if f in last_mtime and mtime > last_mtime[f]:
                    changed = True
                last_mtime[f] = mtime
        if changed:
            print("[Hot Reload] File change detected, reloading browsers...")
            dead_clients = []
            for w in sse_clients:
                try:
                    w.write(b"data: reload\n\n")
                    w.flush()
                except Exception:
                    dead_clients.append(w)
            for d in dead_clients:
                if d in sse_clients:
                    sse_clients.remove(d)

def parse_episodes_from_play_url(play_url):
    """
    Apple CMS 分集解析：格式 源1$$$源2，集1$URL1#集2$URL2
    优先选择包含 .m3u8 的线路，与 LibreTV cms-parser 逻辑一致。
    """
    if not play_url:
        return []
    groups = []
    for g in play_url.split('$$$'):
        eps = []
        for item in g.split('#'):
            if not item.strip():
                continue
            parts = item.split('$')
            if len(parts) >= 2:
                ep_name = parts[0].strip()
                ep_url = parts[1].strip()
            elif len(parts) == 1:
                ep_name = f"第{len(eps)+1}集"
                ep_url = parts[0].strip()
            else:
                continue
            if ep_url.startswith('http://') or ep_url.startswith('https://'):
                eps.append({"ep": ep_name, "name": ep_name, "url": ep_url})
        if eps:
            groups.append(eps)
    
    if not groups:
        return []
    # 优先选含 .m3u8 的分组
    for g in groups:
        if any('.m3u8' in e['url'] for e in g):
            return g
    return groups[0]

def search_single_cms(source, keyword):
    """
    对单个 Apple CMS 采集站发起搜索请求
    """
    base_url = source.get('url', '').rstrip('/')
    source_name = source.get('name', 'CMS源')
    if not base_url:
        return []
    
    # 组合搜索 API
    sep = '&' if '?' in base_url else '?'
    target_url = f"{base_url}{sep}ac=videolist&wd={urllib.parse.quote(keyword)}"
    req = urllib.request.Request(
        target_url,
        headers={
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
            'Accept': 'application/json'
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=6) as response:
            raw_text = response.read().decode('utf-8', errors='ignore')
            data = json.loads(raw_text)
            vod_list = data.get('list', [])
            if not isinstance(vod_list, list):
                return []
            
            results = []
            for item in vod_list:
                title = str(item.get('vod_name', '')).strip()
                if not title:
                    continue
                episodes = parse_episodes_from_play_url(item.get('vod_play_url', ''))
                results.append({
                    'id': f"{source_name}_{item.get('vod_id', '')}",
                    'rawId': str(item.get('vod_id', '')),
                    'title': title,
                    'type': item.get('type_name', '影视'),
                    'year': item.get('vod_year', '2024'),
                    'area': item.get('vod_area', '中国大陆'),
                    'score': item.get('vod_score', '9.0') or '9.0',
                    'badge': item.get('vod_remarks', '') or f"{source_name} 4K",
                    'poster': item.get('vod_pic', ''),
                    'desc': re.sub(r'<[^>]+>', '', str(item.get('vod_content', ''))).strip(),
                    'source': source_name,
                    'sourceUrl': base_url,
                    'episodes': episodes
                })
            return results
    except Exception as e:
        return []

def aggregate_search(keyword, sources=None):
    """
    并行向所有源发起搜索，并按片名跨源聚合
    """
    search_sources = sources or DEFAULT_CMS_SOURCES
    all_items = []
    with ThreadPoolExecutor(max_workers=min(len(search_sources), 8)) as executor:
        future_map = {executor.submit(search_single_cms, s, keyword): s for s in search_sources}
        for future in as_completed(future_map):
            try:
                res = future.result()
                if res:
                    all_items.extend(res)
            except Exception:
                pass

    # 跨源聚合：同名合并，保留所有源的线路
    aggregated = {}
    for item in all_items:
        clean_title = re.sub(r'[\s\-_]+', '', item['title']).lower()
        if clean_title not in aggregated:
            aggregated[clean_title] = {
                'id': item['id'],
                'title': item['title'],
                'type': item['type'],
                'year': item['year'],
                'area': item['area'],
                'score': item['score'],
                'badge': item['badge'],
                'poster': item['poster'],
                'desc': item['desc'],
                'sources': [item['source']],
                'episodes': item['episodes'],
                'allVersions': [{
                    'source': item['source'],
                    'sourceUrl': item['sourceUrl'],
                    'rawId': item['rawId'],
                    'episodes': item['episodes']
                }]
            }
        else:
            agg = aggregated[clean_title]
            if item['source'] not in agg['sources']:
                agg['sources'].append(item['source'])
            # 若已有源无剧集或当前源剧集更多，补充剧集
            if len(item['episodes']) > len(agg['episodes']):
                agg['episodes'] = item['episodes']
            if not agg['poster'] and item['poster']:
                agg['poster'] = item['poster']
            agg['allVersions'].append({
                'source': item['source'],
                'sourceUrl': item['sourceUrl'],
                'rawId': item['rawId'],
                'episodes': item['episodes']
            })

    return list(aggregated.values())

class HotReloadHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        raw_query = parsed.query
        try:
            # Fix http.server default latin-1 decoding of raw URLs
            raw_query = raw_query.encode('latin-1').decode('utf-8')
        except Exception:
            pass
        query = urllib.parse.parse_qs(raw_query)

        # 1. Hot Reload SSE
        if path == '/hot-reload-events':
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Connection', 'keep-alive')
            self.end_headers()
            sse_clients.append(self.wfile)
            try:
                while True:
                    time.sleep(10)
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()
            except Exception:
                if self.wfile in sse_clients:
                    sse_clients.remove(self.wfile)
            return

        # 2. LibreTV SourceList Subscription JSON
        if path == '/api/source-list':
            source_file = os.path.join(DIRECTORY, 'libretv_sources.json')
            if os.path.exists(source_file):
                with open(source_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                return self.send_json(data)
            return self.send_json({"sources": DEFAULT_CMS_SOURCES, "liveSources": []})

        # 3. Image Proxy (Bypasses Douban/Weibo anti-hotlinking)
        if path == '/api/proxy':
            target_url = query.get('url', [''])[0]
            if not target_url or not target_url.startswith(('http://', 'https://')):
                self.send_response(400)
                self.end_headers()
                return
            try:
                headers = {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                    'Referer': 'https://movie.douban.com/'
                }
                req = urllib.request.Request(target_url, headers=headers)
                with urllib.request.urlopen(req, timeout=8) as r:
                    content_type = r.headers.get('Content-Type', 'image/jpeg')
                    body = r.read()
                    self.send_response(200)
                    self.send_header('Content-Type', content_type)
                    self.send_header('Cache-Control', 'public, max-age=86400')
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    return
            except Exception as e:
                self.send_response(502)
                self.end_headers()
                return

        # 4. Douban Recommendations (LibreTV Douban Module)
        if path == '/api/douban':
            category_type = query.get('type', ['movie'])[0]
            tag = query.get('tag', ['热门'])[0]
            page_start = query.get('page_start', ['0'])[0]
            page_limit = query.get('page_limit', ['20'])[0]

            cache_key = f"douban:{category_type}:{tag}:{page_start}:{page_limit}"
            cached = get_cached(cache_key)
            if cached:
                return self.send_json(cached)

            douban_url = f"https://movie.douban.com/j/search_subjects?type={category_type}&tag={urllib.parse.quote(tag)}&sort=recommend&page_limit={page_limit}&page_start={page_start}"
            req = urllib.request.Request(
                douban_url,
                headers={
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                    'Referer': 'https://movie.douban.com/',
                    'Accept': 'application/json'
                }
            )
            try:
                with urllib.request.urlopen(req, timeout=6) as r:
                    raw = json.loads(r.read().decode('utf-8'))
                    subjects = raw.get('subjects', [])
                    items = []
                    for s in subjects:
                        items.append({
                            'id': s.get('id'),
                            'title': s.get('title'),
                            'score': s.get('rate') or '8.5',
                            'poster': f"/api/proxy?url={urllib.parse.quote(s.get('cover', ''))}",
                            'rawPoster': s.get('cover', ''),
                            'year': '2024',
                            'badge': '豆瓣高分',
                            'type': '电影' if category_type == 'movie' else '剧集'
                        })
                    res = {'items': items}
                    set_cached(cache_key, res, 600)
                    return self.send_json(res)
            except Exception as e:
                return self.send_json({'items': [], 'error': str(e)})

        # 5. Hot List (60s API - Douban Weekly & Baidu Teleplay)
        if path == '/api/hot-list':
            list_id = query.get('id', ['douban_movie_weekly'])[0]
            cache_key = f"hotlist:{list_id}"
            cached = get_cached(cache_key)
            if cached:
                return self.send_json(cached)

            sub_path = '/v2/douban/weekly/movie'
            if list_id == 'baidu_teleplay':
                sub_path = '/v2/baidu/teleplay'
            elif list_id == 'douban_tv_chinese':
                sub_path = '/v2/douban/weekly/tv_chinese'
            elif list_id == 'douban_tv_global':
                sub_path = '/v2/douban/weekly/tv_global'

            for base in ['https://60s.crystelf.top', 'https://60s.viki.moe']:
                try:
                    req = urllib.request.Request(
                        base + sub_path,
                        headers={'User-Agent': 'LibreTV (+https://github.com/LibreSpark/LibreTV)', 'Accept': 'application/json'}
                    )
                    with urllib.request.urlopen(req, timeout=6) as r:
                        raw = json.loads(r.read().decode('utf-8'))
                        data_list = raw.get('data', [])
                        items = []
                        for idx, s in enumerate(data_list):
                            title = s.get('title', '')
                            if not title:
                                continue
                            raw_cover = s.get('cover') or s.get('cover_proxy') or ''
                            poster = f"/api/proxy?url={urllib.parse.quote(raw_cover)}" if raw_cover else ''
                            rating = s.get('rating')
                            score = f"{rating:.1f}" if rating and rating > 0 else "9.2"
                            items.append({
                                'id': f"hot_{idx}",
                                'title': title,
                                'score': score,
                                'poster': poster,
                                'rawPoster': raw_cover,
                                'badge': '影视周榜' if 'douban' in list_id else '热播TOP',
                                'year': '2024',
                                'type': '电视剧' if 'teleplay' in list_id or 'tv' in list_id else '电影'
                            })
                        res = {'items': items}
                        set_cached(cache_key, res, 1800)
                        return self.send_json(res)
                except Exception:
                    continue
            return self.send_json({'items': [], 'error': 'Failed to fetch hot list'})

        # 6. Bangumi Anime Calendar (LibreTV Bangumi Module)
        if path == '/api/bangumi':
            cache_key = "bangumi:calendar"
            cached = get_cached(cache_key)
            if cached:
                return self.send_json(cached)

            req = urllib.request.Request(
                'https://api.bgm.tv/calendar',
                headers={'User-Agent': 'LibreTV (+https://github.com/LibreSpark/LibreTV)', 'Accept': 'application/json'}
            )
            try:
                with urllib.request.urlopen(req, timeout=6) as r:
                    raw = json.loads(r.read().decode('utf-8'))
                    days = []
                    for day in raw:
                        weekday_name = day.get('weekday', {}).get('cn', '')
                        items = []
                        for sub in day.get('items', []):
                            title = sub.get('name_cn') or sub.get('name')
                            if not title:
                                continue
                            images = sub.get('images', {})
                            cover = images.get('large') or images.get('common') or images.get('medium') or ''
                            rating = sub.get('rating', {}).get('score')
                            score = f"{rating:.1f}" if rating and rating > 0 else "8.8"
                            items.append({
                                'id': str(sub.get('id')),
                                'title': title,
                                'score': score,
                                'poster': f"/api/proxy?url={urllib.parse.quote(cover)}" if cover else '',
                                'rawPoster': cover,
                                'badge': weekday_name,
                                'type': '动漫'
                            })
                        days.append({'weekday': weekday_name, 'items': items})
                    res = {'days': days}
                    set_cached(cache_key, res, 1800)
                    return self.send_json(res)
            except Exception as e:
                return self.send_json({'days': [], 'error': str(e)})

        # 7. Video Detail Episode Resolver
        if path == '/api/detail':
            vod_id = query.get('id', [''])[0]
            source_url = query.get('sourceUrl', [''])[0]
            if not vod_id or not source_url:
                return self.send_json({'error': 'Missing id or sourceUrl'}, 400)

            clean_source = source_url.rstrip('/')
            sep = '&' if '?' in clean_source else '?'
            target_url = f"{clean_source}{sep}ac=videolist&ids={urllib.parse.quote(vod_id)}"
            try:
                req = urllib.request.Request(
                    target_url,
                    headers={'User-Agent': 'Mozilla/5.0', 'Accept': 'application/json'}
                )
                with urllib.request.urlopen(req, timeout=6) as r:
                    data = json.loads(r.read().decode('utf-8'))
                    vlist = data.get('list', [])
                    if vlist:
                        vod = vlist[0]
                        eps = parse_episodes_from_play_url(vod.get('vod_play_url', ''))
                        return self.send_json({
                            'id': vod_id,
                            'title': vod.get('vod_name', ''),
                            'episodes': eps,
                            'poster': vod.get('vod_pic', ''),
                            'desc': vod.get('vod_content', ''),
                            'badge': vod.get('vod_remarks', '')
                        })
            except Exception as e:
                return self.send_json({'error': str(e)}, 500)
            return self.send_json({'error': 'Not found'}, 404)

        # 8. GitHub TVBox & LibreTV Sources Search
        if path == '/api/github/search':
            kw = query.get('q', [''])[0] or query.get('keyword', [''])[0]
            sources = search_github_sources(kw)
            return self.send_json({'list': sources, 'count': len(sources), 'keyword': kw})

        # Serve static files and inject Live Reload script into HTML
        file_path = self.translate_path(self.path)
        if os.path.isfile(file_path) and (file_path.endswith('.html') or self.path == '/' or self.path == ''):
            if os.path.isdir(file_path):
                file_path = os.path.join(file_path, 'index.html')
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                hot_script = """
                <script>
                  (function() {
                    var es = new EventSource('/hot-reload-events');
                    es.onmessage = function(e) {
                      if (e.data === 'reload') {
                        console.log('[Hot Reload] Reloading page...');
                        window.location.reload();
                      }
                    };
                  })();
                </script>
                """
                if '</body>' in content:
                    content = content.replace('</body>', hot_script + '</body>')
                else:
                    content += hot_script

                body = content.encode('utf-8')
                self.send_response(200)
                self.send_header('Content-Type', 'text/html; charset=utf-8')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            except Exception:
                pass

        return super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else '{}'
        
        try:
            data = json.loads(body)
        except Exception:
            data = {}

        # 1. Multi-source Parallel Search (LibreTV Core Aggregation)
        if path == '/api/search':
            keyword = data.get('wd') or data.get('text') or ''
            keyword = keyword.strip()
            if not keyword:
                return self.send_json({'list': []})

            sources = data.get('sources')
            results = aggregate_search(keyword, sources=sources)
            return self.send_json({'list': results, 'keyword': keyword, 'count': len(results)})

        # 2. GitHub Sources Search
        if path == '/api/github/search':
            kw = data.get('q') or data.get('keyword') or ''
            sources = search_github_sources(kw)
            return self.send_json({'list': sources, 'count': len(sources), 'keyword': kw})

        # 3. Remote / Cast / Source commands forwarding
        if path in ['/api/remote', '/api/cast', '/api/source']:
            # In web mode, commands can be handled by BroadcastChannel or broadcast locally
            return self.send_json({'status': 'ok', 'cmd': path})

        self.send_json({'error': 'Endpoint not found'}, 404)

if __name__ == '__main__':
    t = threading.Thread(target=check_file_changes, daemon=True)
    t.start()
    
    socketserver.TCPServer.allow_reuse_address = True
    httpd = None
    target_port = PORT
    for attempt_port in [8080, 8000, 8088]:
        try:
            httpd = socketserver.TCPServer(("0.0.0.0", attempt_port), HotReloadHandler)
            target_port = attempt_port
            break
        except Exception:
            continue

    local_ip = '127.0.0.1'
    try:
        import subprocess
        for iface in ['en0', 'en1', 'wlan0']:
            try:
                res = subprocess.check_output(['ipconfig', 'getifaddr', iface], stderr=subprocess.DEVNULL).decode().strip()
                if res:
                    local_ip = res
                    break
            except Exception:
                continue
    except Exception:
        pass

    if httpd:
        print(f"🔥 脆皮TV × LibreTV 聚合服务端启动成功!")
        print(f"👉 本地访问地址: http://localhost:{target_port}")
        print(f"👉 手机/局域网访问地址: http://{local_ip}:{target_port}")
        print(f"✨ 已全面接入 LibreTV 采集聚合搜索、豆瓣推荐、影视榜单与 Bangumi 番剧日历!")
        httpd.serve_forever()
    else:
        print("❌ 无法绑定 HTTP 端口，请检查网络权限。")
