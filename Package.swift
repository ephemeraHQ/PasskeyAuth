// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PasskeyAuth",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PasskeyAuth",
            targets: ["PasskeyAuth"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PasskeyAuth",
            dependencies: [],
            path: "Sources/PasskeyAuth"),
        .testTarget(
            name: "PasskeyAuthTests",
            dependencies: ["PasskeyAuth"],
            path: "Tests/PasskeyAuthTests"),
    ],
    swiftLanguageVersions: [.v5]
)

#if canImport(PackageConfig)
import PackageConfig

let config = PackageConfiguration([
    "swiftlint": [
        "disabled_rules": [
            "trailing_whitespace",
            "todo",
            "line_length"
        ],
        "opt_in_rules": [
            "array_init",
            "attributes",
            "closure_end_indentation",
            "closure_spacing",
            "collection_alignment",
            "contains_over_filter_count",
            "contains_over_filter_is_empty",
            "contains_over_first_not_nil",
            "contains_over_range_nil_comparison",
            "discouraged_object_literal",
            "empty_count",
            "empty_string",
            "empty_xctest",
            "explicit_init",
            "explicit_self",
            "fallthrough",
            "fatal_error_message",
            "first_where",
            "flatmap_over_map_reduce",
            "force_unwrapping",
            "implicit_return",
            "implicitly_unwrapped_optional",
            "joined_default_parameter",
            "last_where",
            "legacy_random",
            "literal_expression_end_indentation",
            "lower_acl_than_parent",
            "modifier_order",
            "multiline_arguments",
            "multiline_arguments_brackets",
            "multiline_function_chains",
            "multiline_literal_brackets",
            "multiline_parameters",
            "multiline_parameters_brackets",
            "operator_usage_whitespace",
            "optional_enum_case_matching",
            "overridden_super_call",
            "override_in_extension",
            "pattern_matching_keywords",
            "prefer_self_type_over_type_of_this",
            "redundant_nil_coalescing",
            "redundant_type_annotation",
            "strict_fileprivate",
            "toggle_bool",
            "unowned_variable_capture",
            "untyped_error_in_catch",
            "vertical_parameter_alignment_on_call",
            "vertical_whitespace_closing_braces",
            "vertical_whitespace_opening_braces",
            "xct_specific_matcher",
            "yoda_condition"
        ],
        "analyzer_rules": [
            "unused_declaration"
        ],
        "line_length": [
            "warning": 120,
            "error": 150,
            "ignores_comments": true,
            "ignores_urls": true
        ],
        "function_body_length": [
            "warning": 50,
            "error": 100
        ],
        "type_body_length": [
            "warning": 300,
            "error": 500
        ],
        "file_length": [
            "warning": 500,
            "error": 1000
        ],
        "cyclomatic_complexity": [
            "warning": 10,
            "error": 20
        ],
        "nesting": [
            "type_level": [
                "warning": 3,
                "error": 4
            ],
            "function_level": [
                "warning": 5,
                "error": 6
            ]
        ],
        "identifier_name": [
            "min_length": 2,
            "max_length": 40,
            "excluded": [
                "id",
                "URL",
                "x",
                "y",
                "to",
                "at",
                "of",
                "up",
                "vm",
                "i",
                "j",
                "k",
                "dx",
                "dy"
            ]
        ],
        "type_name": [
            "min_length": 3,
            "max_length": 50
        ],
        "function_parameter_count": [
            "warning": 6,
            "error": 8
        ],
        "large_tuple": [
            "warning": 3,
            "error": 4
        ],
        "reporter": "xcode"
    ]
])
#endif 
