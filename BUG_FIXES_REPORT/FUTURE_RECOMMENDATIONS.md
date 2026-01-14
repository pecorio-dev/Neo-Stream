# NEO-Stream - Recommandations et Meilleures Pratiques Futures

## 🎯 Vue d'ensemble

Ce document fournit des recommandations pour maintenir la qualité du code et prévenir des bugs similaires à l'avenir.

---

## 📌 Recommandations Immédiates

### 1. Tests Unitaires

#### Models (Priorité HAUTE)
```dart
// test/models/series_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:neostream/data/models/series.dart';

void main() {
  group('Episode', () {
    test('toJson et fromJson doivent être cohérents', () {
      final episode = Episode(
        url: 'https://example.com',
        title: 'Episode 1',
        episodeNumber: 1,
        watchLinks: [],
      );
      
      final json = episode.toJson();
      final restored = Episode.fromJson(json);
      
      expect(restored.episodeNumber, equals(episode.episodeNumber));
      expect(json.containsKey('episode_number'), isTrue);
    });
  });
  
  group('Season', () {
    test('toJson utilise les clés correctes', () {
      final season = Season(
        seasonNumber: 1,
        episodeCount: 10,
        episodes: [],
      );
      
      final json = season.toJson();
      
      expect(json.containsKey('season_number'), isTrue);
      expect(json.containsKey('episodes'), isTrue);
      expect(json.containsKey('season'), isFalse); // Ancienne clé
    });
  });
}
```

#### Widgets (Priorité HAUTE)
```dart
// test/widgets/series_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neostream/presentation/widgets/series_card.dart';

void main() {
  group('SeriesCard', () {
    testWidgets('ne doit pas avoir de Expanded imbriqués', 
      (WidgetTester tester) async {
      // Test que le widget se construit sans erreur
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeriesCard(
              series: mockSeriesCompact,
            ),
          ),
        ),
      );
      
      expect(find.byType(SeriesCard), findsOneWidget);
      expect(find.byType(RenderFlex), findsWidgets); // Pas d'erreur
    });
  });
}
```

### 2. Linting et Analyse de Code

#### Configuration `analysis_options.yaml`
```yaml
# analysis_options.yaml
linter:
  rules:
    # Erreurs
    - avoid_empty_else
    - avoid_null_checks_in_equality_operators
    - avoid_relative_lib_imports
    - avoid_returning_null_for_future
    - avoid_returning_null
    - avoid_returning_this
    - avoid_slow_async_io
    - cancel_subscriptions
    - close_sinks
    - comment_references
    - control_flow_in_finally
    - empty_statements
    - hash_and_equals
    - invariant_booleans
    - iterable_contains_unrelated_type
    - list_remove_unrelated_type
    - literal_only_boolean_expressions
    - no_adjacent_strings_in_list
    - no_duplicate_case_values
    - prefer_void_to_null
    - throw_in_finally
    - unnecessary_statements
    - unrelated_type_equality_checks
    
    # Style
    - always_declare_return_types
    - always_put_control_body_on_new_line
    - always_put_required_named_parameters_first
    - annotate_overrides
    - avoid_bool_logic_in_user_settable_values
    - avoid_classes_with_only_static_members
    - avoid_double_and_int_checks
    - avoid_field_initializers_in_const_classes
    - avoid_function_literals_in_foreach_calls
    - avoid_init_to_null
    - avoid_null_checks_in_equality_operators
    - avoid_positional_boolean_parameters
    - avoid_private_typedef_functions
    - avoid_redundant_argument_values
    - avoid_renaming_method_parameters
    - avoid_returning_null_for_async
    - avoid_returning_null_for_future
    - avoid_returning_null
    - avoid_returning_this
    - avoid_setters_without_getters
    - avoid_shadowing_type_parameters
    - avoid_shell_trigger_in_files
    - avoid_slow_async_io
    - avoid_types_as_parameter_names
    - avoid_types_on_closure_parameters
    - avoid_types_on_loop_variable_names
    - avoid_unnecessary_containers
    - avoid_web_libraries_in_flutter
    - await_only_futures
    - camel_case_extensions
    - camel_case_types
    - cascade_invocations
    - cast_nullable_to_non_nullable
    - catch_blocks_without_on_clauses
    - constant_identifier_names
    - curly_braces_in_flow_control_structures
    - directives_ordering
    - empty_catches
    - empty_constructor_bodies
    - eol_at_end_of_file
    - file_names
    - implementation_imports
    - leading_newlines_in_multiline_strings
    - library_names
    - library_prefixes
    - library_private_types_in_public_api
    - lines_longer_than_80_chars
    - no_leading_underscores_for_library_prefixes
    - no_leading_underscores_for_local_variables
    - null_closures
    - null_check_on_nullable_type_parameter
    - omit_local_variable_types
    - one_member_abstracts
    - only_throw_errors
    - overridden_fields
    - package_api_docs
    - package_names
    - package_prefixed_library_names
    - package_names
    - prefer_adjacent_string_concatenation
    - prefer_asserts_in_initializer_lists
    - prefer_asserts_with_message
    - prefer_async_await
    - prefer_collection_literals
    - prefer_conditional_assignment
    - prefer_const_constructors
    - prefer_const_constructors_in_immutables
    - prefer_const_declarations
    - prefer_const_literals_to_create_immutables
    - prefer_constructors_over_static_methods
    - prefer_contains
    - prefer_equal_for_default_values
    - prefer_expression_function_bodies
    - prefer_final_fields
    - prefer_final_in_for_each
    - prefer_final_locals
    - prefer_for_elements_to_map_fromIterable
    - prefer_foreach
    - prefer_function_declarations_over_variables
    - prefer_generic_function_type_aliases
    - prefer_getters_setters
    - prefer_if_elements_to_conditional_expressions
    - prefer_if_null_to_conditional_expression
    - prefer_if_on_single_line_is_else_if
    - prefer_inline_async_helper
    - prefer_int_literals
    - prefer_interpolation_to_compose_strings
    - prefer_int_literals
    - prefer_intl_name
    - prefer_inlined_adds
    - prefer_is_empty
    - prefer_is_not_empty
    - prefer_is_not_operator
    - prefer_is_operator
    - prefer_null_aware_operators
    - prefer_null_coalescing_operator
    - prefer_null_coalescing_operators
    - prefer_null_in_if_null_operators
    - prefer_null_operators
    - prefer_relative_imports
    - prefer_relative_imports
    - prefer_single_quotes
    - prefer_spread_collections
    - prefer_typing_uninitialized_variables
    - provide_deprecation_message
    - recursive_getters
    - sized_box_for_spacer
    - sized_box_shrink_expand
    - slash_for_doc_comments
    - sort_child_properties_last
    - sort_constructors_first
    - sort_pub_dependencies
    - sort_unnamed_constructors_first
    - tighten_type_of_initializing_formals
    - type_annotate_public_apis
    - type_init_formals
    - unawaited_futures
    - unnecessary_await_in_return
    - unnecessary_brace_in_string_interps
    - unnecessary_const
    - unnecessary_constructor_name
    - unnecessary_getters_setters
    - unnecessary_getters
    - unnecessary_lambdas
    - unnecessary_library_directive
    - unnecessary_new
    - unnecessary_null_aware_assignments
    - unnecessary_null_checks
    - unnecessary_null_in_if_null_operators
    - unnecessary_null_operator_on_extension_on_nullable_type
    - unnecessary_null_on_extension_on_nullable_type
    - unnecessary_nullable_for_final_variable_declarations
    - unnecessary_overrides
    - unnecessary_parenthesis
    - unnecessary_raw_strings
    - unnecessary_statements
    - unnecessary_string_escapes
    - unnecessary_string_interpolations
    - unnecessary_to_list_in_spreads
    - unnecessary_tolist_in_spreads
    - unrelated_type_equality_checks
    - unsafe_html
    - use_build_context_synchronously
    - use_full_hex_values_for_flutter_colors
    - use_function_type_syntax_for_parameters
    - use_getters_to_change_properties
    - use_if_null_to_convert_nulls
    - use_is_even_rather_than_modulo
    - use_key_in_widget_constructors
    - use_late_for_private_fields_and_variables
    - use_null_coalescing_operator
    - use_raw_strings
    - use_rethrow_when_possible
    - use_setters_to_change_properties
    - use_string_buffers
    - use_test_throws_matchers
    - use_to_close_annotated_classes
    - use_underscores_to_denote_unused_callback_parameters
    - use_underscores_to_denote_unused_callback_parameters
    - void_checks
```

### 3. Documentation du Code

#### Exemple: Module Extractor
```dart
/// Extracteur de flux vidéo Uqload
/// 
/// Ce service extrait les informations de stream depuis les URLs Uqload.
/// 
/// Exemple d'utilisation:
/// ```dart
/// final streamInfo = await UqloadExtractor.extractStreamInfo(url);
/// // streamInfo contient l'URL directe et les headers
/// ```
/// 
/// **Note**: Les URLs Uqload changent fréquemment. Si l'extraction échoue,
/// il est possible que le format de la page ait changé.
class UqloadExtractor {
  /// Extrait les informations de stream depuis une URL Uqload
  /// 
  /// [url] : L'URL Uqload à traiter
  /// 
  /// Retourne un [StreamInfo] contenant:
  /// - L'URL directe du flux vidéo
  /// - Les headers HTTP nécessaires
  /// - La qualité détectée
  /// - Le titre de la vidéo
  /// 
  /// Throws [Exception] si l'extraction échoue
  static Future<StreamInfo> extractStreamInfo(String url) async {
    // ...
  }
}
```

---

## 🏗️ Architecture et Patterns

### 1. Pattern: Repository avec Cache

```dart
/// Repository pour les films avec gestion du cache
abstract class MovieRepository {
  Future<List<Movie>> getMovies({
    int page = 1,
    bool forceRefresh = false,
  });
}

class MovieRepositoryImpl implements MovieRepository {
  final MovieApiService _apiService;
  final MovieCacheService _cacheService;
  
  @override
  Future<List<Movie>> getMovies({
    int page = 1,
    bool forceRefresh = false,
  }) async {
    // 1. Vérifier le cache si pas de refresh forcé
    if (!forceRefresh) {
      final cached = await _cacheService.getMovies(page);
      if (cached.isNotEmpty) {
        return cached;
      }
    }
    
    // 2. Fetcher depuis l'API
    final movies = await _apiService.getMovies(page: page);
    
    // 3. Sauvegarder en cache
    await _cacheService.saveMovies(page, movies);
    
    return movies;
  }
}
```

### 2. Pattern: Provider avec State Management

```dart
/// Provider pour gérer l'état des films
class MovieProvider extends ChangeNotifier {
  // State privé
  List<Movie> _movies = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  
  // Getters publics
  List<Movie> get movies => _movies;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  // Public methods
  Future<void> loadMovies() async {
    _setLoading(true);
    _setError(null);
    
    try {
      _movies = await _movieRepository.getMovies();
      _currentPage = 1;
    } catch (e) {
      _setError(e.toString());
    }
    
    _setLoading(false);
  }
}
```

---

## 🔍 Prévention des Bugs Courants

### 1. Erreurs de Layout

#### ❌ À ÉVITER
```dart
// Double Expanded
Column(
  children: [
    Expanded(
      child: Expanded(
        child: Widget(),
      ),
    ),
  ],
)

// Expanded dans ListTile.title
ListTile(
  title: Expanded(child: Text('...')),
)

// Pas de contrainte pour Row/Column
Row(
  children: [
    Text('Long text that might overflow'),
  ],
)
```

#### ✅ FAIRE
```dart
// Utiliser SizedBox ou Flexible
Column(
  children: [
    SizedBox(
      height: 200,
      child: Widget(),
    ),
  ],
)

// Utiliser Row directement
ListTile(
  title: Row(
    children: [
      Expanded(child: Text('...')),
    ],
  ),
)

// Utiliser Expanded pour les textes longs
Row(
  children: [
    Expanded(
      child: Text('Long text that might overflow'),
    ),
  ],
)
```

### 2. Erreurs de JSON

#### ❌ À ÉVITER
```dart
// Clés incohérentes
factory MyModel.fromJson(Map<String, dynamic> json) {
  return MyModel(
    name: json['name'],
    age: json['age'],
  );
}

Map<String, dynamic> toJson() {
  return {
    'user_name': name,    // Différent de 'name'
    'user_age': age,      // Différent de 'age'
  };
}
```

#### ✅ FAIRE
```dart
// Clés cohérentes
factory MyModel.fromJson(Map<String, dynamic> json) {
  return MyModel(
    name: json['name'],
    age: json['age'],
  );
}

Map<String, dynamic> toJson() {
  return {
    'name': name,
    'age': age,
  };
}

// Ajouter des tests
test('JSON cohérence', () {
  final original = MyModel(name: 'John', age: 30);
  final json = original.toJson();
  final restored = MyModel.fromJson(json);
  expect(restored.name, equals(original.name));
});
```

### 3. Erreurs de Null Safety

#### ❌ À ÉVITER
```dart
// Force unwrapping
String name = widget.user!.name!;

// Comparaisons avec null
if (value == null) { ... } // Redondant avec nullable

// Null checks tardifs
final result = data?.property; // Peut être null sans warning
print(result.length); // Crash potentiel
```

#### ✅ FAIRE
```dart
// Null coalescing
String name = widget.user?.name ?? 'Unknown';

// Pattern matching
if (value case final v?) {
  // v est non-null
} else {
  // value est null
}

// Vérification précoce
final result = data?.property;
if (result != null) {
  print(result.length);
}
```

---

## 📚 Checklist de Code Review

### Avant de Commiter

- [ ] Code compile sans erreurs
- [ ] Pas d'avertissements du linter
- [ ] Tests ajoutés pour les nouvelles fonctionnalités
- [ ] Pas de code mort ou commenté
- [ ] Noms significatifs pour variables/fonctions
- [ ] Documentation ajoutée pour API publiques
- [ ] Pas de hardcoded values (strings, numbers)
- [ ] Gestion d'erreurs appropriée
- [ ] Pas de duplications de code
- [ ] Performance vérifiée

### Pour les Modèles JSON

- [ ] `fromJson()` et `toJson()` utilisent les mêmes clés
- [ ] Valeurs par défaut définies
- [ ] Types correctement mappés
- [ ] Tests de sérialisation/désérialisation
- [ ] Documentation des champs JSON

### Pour les Widgets

- [ ] Pas d'Expanded imbriqués inutiles
- [ ] Pas de overflow horizontaux/verticaux
- [ ] Responsive sur différentes tailles
- [ ] Tests de layout
- [ ] Accessibility labels présents

---

## 🔄 Processus de Maintenance

### Audit Mensuel

```bash
# 1. Vérifier les avertissements
flutter analyze

# 2. Formater le code
dart format lib/

# 3. Lancer les tests
flutter test

# 4. Vérifier les performances
flutter run --profile
```

### Mise à Jour des Dépendances

```bash
# Vérifier les mises à jour
flutter pub outdated

# Mettre à jour sécurisé
flutter pub upgrade --dry-run

# Appliquer les mises à jour
flutter pub upgrade
```

---

## 📖 Ressources Recommandées

1. **Flutter Best Practices**
   - https://flutter.dev/docs/testing/best-practices
   
2. **Dart Style Guide**
   - https://dart.dev/guides/language/effective-dart/style
   
3. **Provider Documentation**
   - https://pub.dev/packages/provider
   
4. **Flutter Performance**
   - https://flutter.dev/docs/perf/rendering/best-practices

---

## 🎯 Prochaines Étapes

1. **Court terme (1-2 semaines)**
   - [x] Corriger les bugs trouvés
   - [ ] Ajouter les tests unitaires
   - [ ] Configurer le CI/CD

2. **Moyen terme (1-2 mois)**
   - [ ] Augmenter la couverture de tests (80%)
   - [ ] Ajouter les tests d'intégration
   - [ ] Documentation API complète

3. **Long terme (3-6 mois)**
   - [ ] Refactorisation architecture
   - [ ] Performance optimization
   - [ ] Monitoring et logging

---

**Dernière mise à jour**: 2024  
**Status**: ✅ Recommandations Finalisées