import 'package:equatable/equatable.dart';

/// Per-category detail-field schema (decision 47) as served by
/// `GET /app-reports/category-forms`. Rendering is fully driven by this —
/// no per-category hardcoded widget (spec task 21).
class CategoryFormSchemaEntity extends Equatable {
  const CategoryFormSchemaEntity({required this.category, required this.fields});

  final String category;
  final List<CategoryFormField> fields;

  factory CategoryFormSchemaEntity.fromJson(Map<String, dynamic> json) =>
      CategoryFormSchemaEntity(
        category: json['category'] as String,
        fields: (json['fields'] as List<dynamic>? ?? const [])
            .map((f) => CategoryFormField.fromJson((f as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'category': category,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  @override
  List<Object?> get props => [category, fields];
}

class CategoryFormField extends Equatable {
  const CategoryFormField({
    required this.name,
    required this.type,
    required this.required_,
  });

  final String name;

  /// `string | number | boolean | date` — the API's FieldType.
  final String type;
  final bool required_;

  factory CategoryFormField.fromJson(Map<String, dynamic> json) => CategoryFormField(
        name: json['name'] as String,
        type: json['type'] as String,
        required_: json['required'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'required': required_};

  @override
  List<Object?> get props => [name, type, required_];
}
