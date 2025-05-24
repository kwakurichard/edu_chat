import 'package:json_annotation/json_annotation.dart';

part 'topic.g.dart';

@JsonSerializable()
class Topic {
  final String id;
  @JsonKey(name: 'subject_id')
  final String subjectId;
  final String name;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  // Add other fields like 'summary' if you plan to store generated notes in Supabase
  // final String? summary;

  Topic({
    required this.id,
    required this.subjectId,
    required this.name,
    required this.createdAt,
    // this.summary,
  });

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
  Map<String, dynamic> toJson() => _$TopicToJson(this);
}