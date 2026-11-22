/// The client data bundle of one SDE build: its format, builder, reader and
/// offline search.
///
/// This package is web-safe: it imports no `dart:io`, `dart:ffi` or
/// `dart:isolate`, so the app's web build can use it (`kaname_tools purity`
/// enforces this).
library;

export 'src/bundle_builder.dart';
export 'src/bundle_format.dart'
    show bundleFormatMajor, bundleFormatMinor, bundleLocales, bundleMaxKey;
export 'src/bundle_models.dart';
export 'src/bundle_reader.dart';
export 'src/bundle_section.dart';
export 'src/search_index.dart';
