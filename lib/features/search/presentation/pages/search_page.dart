import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../chat/domain/entities/conversation_entity.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/domain/usecases/get_feed_usecase.dart';

/// The live backend has no `/search` endpoint of any kind — this searches
/// only what's already loaded client-side (the cached feed + conversation
/// list), rather than pretending to be a full people/post search. A real
/// search feature belongs in `domain/`+`data/` layers like every other
/// feature once the backend actually offers one; until then, dressing this
/// up with a fake repository would just be ceremony around nothing.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  List<PostEntity> _posts = [];
  List<ConversationEntity> _conversations = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCorpus();
  }

  Future<void> _loadCorpus() async {
    final feedResult = await sl<GetFeedUseCase>()(const GetFeedParams());
    final convoResult = await sl<GetConversationsUseCase>()(
      const CursorParams(),
    );
    if (!mounted) return;
    setState(() {
      _posts = feedResult.fold((_) => [], (page) => page.posts);
      _conversations = convoResult.fold(
        (_) => [],
        (page) => page.conversations,
      );
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final q = _query.trim().toLowerCase();
    final matchedPosts = q.isEmpty
        ? const <PostEntity>[]
        : _posts
              .where(
                (p) =>
                    p.content.toLowerCase().contains(q) ||
                    p.authorUsername.toLowerCase().contains(q),
              )
              .toList();
    final matchedConvos = q.isEmpty
        ? const <ConversationEntity>[]
        : _conversations
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surf,
                        border: Border.all(color: colors.line, width: 1.5),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        style: AppTextStyles.hint.copyWith(color: colors.ink),
                        decoration: InputDecoration(
                          hintText: 'Search people, posts',
                          hintStyle: AppTextStyles.hint.copyWith(
                            color: colors.ink3,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : q.isEmpty
                  ? Center(
                      child: Text(
                        'Search what you have already loaded.',
                        style: AppTextStyles.bodySm.copyWith(
                          color: colors.ink2,
                        ),
                      ),
                    )
                  : matchedPosts.isEmpty && matchedConvos.isEmpty
                  ? Center(
                      child: Text(
                        'No matches for "$q"',
                        style: AppTextStyles.bodySm.copyWith(
                          color: colors.ink2,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      children: [
                        if (matchedConvos.isNotEmpty) ...[
                          Text(
                            'PEOPLE',
                            style: AppTextStyles.eyebrow.copyWith(
                              color: colors.ink2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final c in matchedConvos)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AppAvatar(
                                initials: c.name.initials,
                                seed: c.avatarSeed,
                                size: 40,
                              ),
                              title: Text(
                                c.name,
                                style: AppTextStyles.titleMd.copyWith(
                                  color: colors.ink,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                        if (matchedPosts.isNotEmpty) ...[
                          Text(
                            'POSTS',
                            style: AppTextStyles.eyebrow.copyWith(
                              color: colors.ink2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final p in matchedPosts)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AppAvatar(
                                initials: p.authorUsername.initials,
                                seed: avatarSeedForId(p.authorId),
                                imageUrl: p.authorAvatarUrl,
                                size: 40,
                              ),
                              title: Text(
                                '@${p.authorUsername}',
                                style: AppTextStyles.titleMd.copyWith(
                                  color: colors.ink,
                                ),
                              ),
                              subtitle: Text(
                                p.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySm.copyWith(
                                  color: colors.ink2,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
