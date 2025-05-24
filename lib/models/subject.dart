import 'package:json_annotation/json_annotation.dart';

part 'subject.g.dart';

@JsonSerializable()
class Subject {
  final String id;
  final String name;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Subject({required this.id, required this.name, required this.createdAt});

  // Factory method for creating a temporary subject when the real one is not found
  factory Subject.temporary(String name) {
    return Subject(
      id: 'temp-${name.toLowerCase().replaceAll(' ', '-')}',
      name: name,
      createdAt: DateTime.now(),
    );
  }

  factory Subject.fromJson(Map<String, dynamic> json) =>
      _$SubjectFromJson(json);
  Map<String, dynamic> toJson() => _$SubjectToJson(this);
}
