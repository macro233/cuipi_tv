import 'dart:io';
import 'package:flutter/material.dart';
import '../services/media_cache_service.dart';

class CachedPosterImage extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String? category;
  final String? score;
  final BoxFit fit;
  final double? width;
  final double? height;

  const CachedPosterImage({
    Key? key,
    required this.imageUrl,
    required this.title,
    this.category,
    this.score,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<CachedPosterImage> createState() => _CachedPosterImageState();
}

class _CachedPosterImageState extends State<CachedPosterImage> {
  final MediaCacheService _cacheService = MediaCacheService();
  File? _localFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(CachedPosterImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.title != widget.title) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    if (widget.imageUrl.startsWith('assets/')) {
      return;
    }

    if (widget.imageUrl.startsWith('/')) {
      final f = File(widget.imageUrl);
      if (f.existsSync()) {
        setState(() => _localFile = f);
        return;
      }
    }

    // 检查本地持久化磁盘缓存
    final cached = _cacheService.getCacheFile(widget.imageUrl);
    if (cached != null && cached.existsSync() && cached.lengthSync() > 500) {
      setState(() => _localFile = cached);
      return;
    }

    // 未在本地缓存：启动静默异步下载并缓存至磁盘
    if (widget.imageUrl.startsWith('http') && !_isLoading) {
      _isLoading = true;
      _cacheService.downloadAndCache(widget.imageUrl).then((file) {
        if (mounted && file != null && file.existsSync()) {
          setState(() {
            _localFile = file;
            _isLoading = false;
          });
        }
      }).catchError((_) {
        if (mounted) setState(() => _isLoading = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. 本地磁盘缓存已就绪 -> 零等待硬解渲染
    if (_localFile != null && _localFile!.existsSync()) {
      return Image.file(
        _localFile!,
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        fit: widget.fit,
        errorBuilder: (c, e, s) => _buildFallbackCard(),
      );
    }

    // 2. assets 内置海报
    if (widget.imageUrl.startsWith('assets/')) {
      return Image.asset(
        widget.imageUrl,
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        fit: widget.fit,
        errorBuilder: (c, e, s) => _buildFallbackCard(),
      );
    }

    // 3. 智能本地资产兜底匹配
    final bundledAsset = MediaCacheService.getBundledAssetForTitle(widget.title);
    if (bundledAsset.isNotEmpty) {
      return Image.asset(
        bundledAsset,
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        fit: widget.fit,
        errorBuilder: (c, e, s) => _buildFallbackCard(),
      );
    }

    // 4. 网络图片（带安全代理及防盗链头）
    if (widget.imageUrl.startsWith('http')) {
      String cleanUrl = widget.imageUrl;
      if (cleanUrl.startsWith('http://')) {
        cleanUrl = 'https://${cleanUrl.substring(7)}';
      }
      final isDouban = cleanUrl.contains('doubanio.com') || cleanUrl.contains('douban.com');

      return Image.network(
        cleanUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
          'Accept': 'image/*,*/*;q=0.8',
          if (isDouban) 'Referer': 'https://movie.douban.com/',
        },
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        fit: widget.fit,
        errorBuilder: (c, e, s) {
          final proxied = 'https://images.weserv.nl/?url=${Uri.encodeComponent(cleanUrl)}&default=1';
          return Image.network(
            proxied,
            width: widget.width ?? double.infinity,
            height: widget.height ?? double.infinity,
            fit: widget.fit,
            errorBuilder: (ctx, err, stack) => _buildFallbackCard(),
          );
        },
      );
    }

    return _buildFallbackCard();
  }

  Widget _buildFallbackCard() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.movie_outlined, color: Color(0xFF38BDF8), size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (widget.category != null && widget.category!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.category!,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
