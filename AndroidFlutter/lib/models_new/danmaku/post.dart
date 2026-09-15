class DanmakuPost {
  DanmakuPost({
    required this.dmid,
  });

  final int? dmid;

  factory DanmakuPost.fromJson(Map<String, dynamic> json) {
    return DanmakuPost(
      dmid: switch (json['dmid']) {
        final int id => id,
        final String id => int.tryParse(id),
        _ => null,
      },
    );
  }
}
