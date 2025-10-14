# Repository Guidelines

## Project Structure & Module Organization
The Flutter app lives in `lib/`, split by domain: `lib/core` for base services and utilities, `lib/shared` for reusable UI, and `lib/features/*` for feature slices such as `auth`, `events`, and `hours_approval`. App bootstrap code sits in `lib/main.dart` and `lib/app.dart`. Platform shells are under `android/`, `ios/`, `macos/`, `linux/`, `windows/`, and `web/`. Shared assets are in `assets/`, while backend adapters and scripts reside in `backend/`. Use the `test/` folder for unit and widget tests; mirror the feature folder structure when adding new coverage.

## Build, Test, and Development Commands
- Run the app: `flutter run -d <device>` from the repo root.
- Hot-reload friendly web build: `flutter run -d chrome`.
- Static analysis: `flutter analyze`.
- Format code: `dart format .`.
- Execute tests: `flutter test`.
- Regenerate code for freezed/json/injectable models: `flutter pub run build_runner build --delete-conflicting-outputs`.
- Update dependencies: `flutter pub get`.

## Coding Style & Naming Conventions
Follow the default `flutter_lints` rules with two-space indentation. Prefer `PascalCase` for classes and widgets, `camelCase` for variables/functions, and `snake_case` for file names (e.g., `client_repository.dart`). Keep feature modules self-contained: domain models in `domain/`, data sources in `data/`, presentation logic in `presentation/`. Document complex blocs or services with short doc comments, and favor dependency injection via `get_it`/`injectable` over manual instantiation.

## Testing Guidelines
Use `flutter_test`, `bloc_test`, and `mocktail` for unit and widget coverage; organize tests to mirror `lib/` paths (e.g., `test/features/auth/presentation/login_bloc_test.dart`). Aim to cover new blocs, repositories, and critical widgets. When snapshots are needed, prefer golden tests stored under `test/goldens/`. Run `flutter test` locally before pushing and ensure generated mocks are up to date.

## Commit & Pull Request Guidelines
Write concise, present-tense commit messages (e.g., `Add client filter bloc`, `Fix hours approval dialog state`). Keep related changes in a single commit when possible. Pull requests should include a summary of changes, testing evidence (`flutter test` output or screenshots for UI tweaks), and links to relevant issues or specs (`DELTA_SYNC_QUICKSTART.md`, etc.). Highlight any migration steps (env variables, schema updates) in the PR description.

## Configuration Notes
Provide `.env` values (or `--dart-define`) for `APPLE_SERVICE_ID` and `APPLE_REDIRECT_URI` to enable Apple sign-in on web; mobile builds still rely on `APPLE_BUNDLE_ID`. Align each value with the identifiers registered in Apple developer settings; `APPLE_BUNDLE_ID` accepts a comma-separated list (e.g., `com.pymesoft.nexastaff,com.pymesoft.nexa`) when supporting multiple apps.
    **Last Updated**: 2025-01-15
     **Project Status**: Phase 1 Complete ✅ | Phase 2 In Progress 🔜
     **Architecture**: Clean Architecture (Domain/Data/Presentation)

     ---

     ## 🎯 Project Overview

     ### What is Nexa?
     Nexa is a **Flutter-based event staffing management application** for the catering and hospitality industry. It helps event managers coordinate staff assignments for events by:
     - Extracting event details from documents (PDFs, images) using AI
     - Managing events, clients, staff, roles, and pricing
     - Scheduling and tracking staff assignments
     - Real-time synchronization with minimal data transfer

     ### Core User Workflows
     1. **AI-Powered Event Creation**: Upload event document → AI extracts details → Review/edit → Publish
     2. **Manual Event Creation**: Fill form with event details → Add roles/staff → Save as draft → Publish
     3. **Event Management**: View upcoming/past events → Assign staff → Track progress → Approve hours
     4. **Staff Management**: View available staff → Assign to roles → Manage profiles
     5. **Catalog Management**: Configure clients, roles, and pricing tariffs

     ### Primary Users
     - Event managers/coordinators
     - Catering company administrators
     - Staff members (view their assigned events)

     ---

     ## 🏗️ Architecture Overview

     ### Clean Architecture Layers

     ```
     ┌─────────────────────────────────────┐
     │      PRESENTATION LAYER             │
     │  (UI, BLoCs, Pages, Widgets)        │
     │  - Depends on: Domain Layer         │
     └─────────────────────────────────────┘
                   ↓
     ┌─────────────────────────────────────┐
     │         DOMAIN LAYER                │
     │  (Entities, Repositories,           │
     │   Use Cases, Business Logic)        │
     │  - Pure Dart (no dependencies)      │
     └─────────────────────────────────────┘
                   ↓
     ┌─────────────────────────────────────┐
     │          DATA LAYER                 │
     │  (Models, Data Sources,             │
     │   Repository Implementations)       │
     │  - Depends on: Domain Layer         │
     └─────────────────────────────────────┘
     ```

     ### Current Implementation Status

     | Layer | Status | Notes |
     |-------|--------|-------|
     | **Domain** | ✅ Complete | 71 files: entities, repositories, use cases |
     | **Data** | 🔜 In Progress | Legacy services exist, need migration |
     | **Presentation** | ⚠️ Mixed | Main UI exists but needs BLoC refactoring |
     | **Core** | ✅ Complete | DI, networking, error handling, utils |

     ---

     ## 📁 Codebase Structure

     ### Root Directory Layout

     ```
     nexa/
     ├── lib/
     │   ├── core/                    # Shared infrastructure
     │   ├── features/                # Feature modules (8 features)
     │   ├── shared/                  # Shared UI components
     │   ├── app.dart                 # Root app widget
     │   └── main.dart                # Entry point
     ├── assets/                      # Images, logos
     ├── test/                        # Unit/widget tests
     ├── .env                         # Environment variables (DO NOT commit)
     ├── pubspec.yaml                 # Dependencies
     └── AI_CONTEXT.md                # This file
     ```

     ### Core Infrastructure (`lib/core/`)

     ```
     core/
     ├── config/
     │   ├── environment.dart         # .env loader singleton
     │   ├── app_config.dart          # Centralized config (API URLs, keys)
     │   └── api_endpoints.dart       # All API endpoint constants
     ├── constants/
     │   ├── app_constants.dart       # Timeouts, pagination, UI constants
     │   ├── api_constants.dart       # HTTP headers, status codes
     │   ├── storage_keys.dart        # Keys for secure storage/prefs
     │   └── error_messages.dart      # User-friendly error messages
     ├── domain/
     │   ├── entity.dart              # Base entity interface
     │   └── usecase.dart             # Base UseCase<Type, Params> class
     ├── errors/
     │   ├── exceptions.dart          # 15 custom exception types
     │   ├── failures.dart            # Failure classes (Either pattern)
     │   └── error_handler.dart       # Error conversion utilities
     ├── network/
     │   ├── api_client.dart          # Dio-based HTTP client
     │   ├── dio_interceptors.dart    # Auth, logging, error interceptors
     │   └── network_info.dart        # Connectivity checking
     ├── utils/
     │   ├── validators.dart          # 20+ validation functions
     │   ├── formatters.dart          # Date, currency, phone formatters
     │   ├── logger.dart              # Environment-specific logging
     │   └── extensions/
     │       ├── string_extensions.dart    # 40+ String utilities
     │       ├── date_extensions.dart      # 40+ DateTime utilities
     │       └── context_extensions.dart   # 50+ BuildContext utilities
     ├── di/
     │   ├── injection.dart           # GetIt + Injectable DI setup
     │   └── injection.config.dart    # Generated DI config
     ├── sync/
     │   ├── delta_sync_service.dart  # Delta sync for efficiency
     │   └── README.md                # Delta sync documentation
     └── widgets/
         ├── custom_sliver_app_bar.dart
         └── pinned_header_delegate.dart
     ```

     ### Feature Modules (`lib/features/`)

     Each feature follows the same structure:

     ```
     features/{feature_name}/
     ├── domain/
     │   ├── entities/                # Business objects (Freezed)
     │   ├── repositories/            # Repository interfaces
     │   └── usecases/                # One use case per operation
     ├── data/                        # ⚠️ Mostly incomplete
     │   ├── models/                  # DTOs with JSON serialization
     │   ├── datasources/             # Remote/Local data sources
     │   └── repositories/            # Repository implementations
     └── presentation/                # ⚠️ Mixed state
         ├── bloc/                    # BLoCs/Cubits (mostly TODO)
         ├── pages/                   # Screens
         └── widgets/                 # Feature-specific widgets
     ```

     ---

     ## 🎨 Features Breakdown

     ### 1. **Events Feature** (`features/events/`)
     **Purpose**: Core feature for managing catering/hospitality events

     **Domain Layer** (✅ Complete):
     - Entities: `Event`, `Address`, `EventRole`, `EventStatus`
     - Repository: `EventRepository` (11 methods)
     - Use Cases: 7 use cases (CRUD + upcoming/past/by-status)

     **Key Properties**:
     - Event scheduling (start/end dates, setup time)
     - Location (venue name, address with lat/lng)
     - Client association
     - Role assignments (waiters, chefs, bartenders, etc.)
     - Contact information
     - Status tracking (draft → pending → confirmed → in progress → completed)

     **Data Layer** (⚠️ Legacy):
     - `features/extraction/services/event_service.dart` - needs migration to data layer

     ### 2. **Clients Feature** (`features/clients/`)
     **Purpose**: Manage event clients (companies/organizations)

     **Domain Layer** (✅ Complete):
     - Entity: `Client`
     - Repository: `ClientRepository` (7 methods)
     - Use Cases: 6 use cases (CRUD + search)

     **Data Layer** (⚠️ Legacy):
     - `features/extraction/services/clients_service.dart` - needs migration

     ### 3. **Users Feature** (`features/users/`)
     **Purpose**: Staff member management and profiles

     **Domain Layer** (✅ Complete):
     - Entity: `User` (staff members with certifications, roles, availability)
     - Repository: `UserRepository` (7 methods with pagination)
     - Use Cases: 6 use cases (CRUD + search)

     **Presentation Layer** (✅ Partial):
     - `manager_profile_page.dart` - Manager profile view
     - `user_events_screen.dart` - Staff member's assigned events
     - `settings_page.dart` - App settings

     **Data Layer** (⚠️ Legacy):
     - `features/extraction/services/users_service.dart` - needs migration
     - `features/users/data/services/manager_service.dart` - profile management

     ### 4. **Roles Feature** (`features/roles/`)
     **Purpose**: Job role definitions (waiter, chef, bartender, etc.)

     **Domain Layer** (✅ Complete):
     - Entity: `Role` (with skills, requirements, descriptions)
     - Repository: `RoleRepository` (7 methods)
     - Use Cases: 6 use cases (CRUD + get active roles)

     **Data Layer** (⚠️ Legacy):
     - `features/extraction/services/roles_service.dart` - needs migration

     ### 5. **Tariffs Feature** (`features/tariffs/`)
     **Purpose**: Pricing management (rates per client/role combination)

     **Domain Layer** (✅ Complete):
     - Entity: `Tariff` (hourly rates, client-role specific)
     - Repository: `TariffRepository` (8 methods)
     - Use Cases: 6 use cases (CRUD + get by client and role)

     **Data Layer** (⚠️ Legacy):
     - `features/extraction/services/tariffs_service.dart` - needs migration

     ### 6. **Extraction Feature** (`features/extraction/`)
     **Purpose**: AI-powered document extraction (PDF/image → event data)

     **Domain Layer** (✅ Complete):
     - Entities: `ExtractedData`, `ExtractionRequest`
     - Repository: `ExtractionRepository` (6 methods)
     - Use Cases: 5 use cases (extract from PDF/image/text, parse structured data)

     **Presentation Layer** (⚠️ Monolithic):
     - `extraction_screen.dart` - **3,303 lines** (needs breaking down!)
       - Contains: Upload UI, manual entry form, events list, users list, catalog
       - Should be split into separate screens
     - `pending_publish_screen.dart` - Review pending events
     - `pending_edit_screen.dart` - Edit pending events

     **Data Layer** (⚠️ Legacy):
     - `services/extraction_service.dart` - OpenAI API integration
     - `services/google_places_service.dart` - Address autocomplete
     - `services/pending_events_service.dart` - Draft management

     ### 7. **Drafts Feature** (`features/drafts/`)
     **Purpose**: Auto-save event drafts locally

     **Domain Layer** (✅ Complete):
     - Entity: `Draft`
     - Repository: `DraftRepository` (6 methods)
     - Use Cases: 5 use cases (save, load, delete, list, clear all)

     **Data Layer** (⚠️ Legacy):
     - `features/extraction/services/draft_service.dart` - uses SharedPreferences

     ### 8. **Auth Feature** (`features/auth/`)
     **Purpose**: User authentication (Google, Apple Sign-In)

     **Domain Layer** (✅ Complete):
     - Entities: `AuthUser`, `AuthCredentials` (Freezed union type)
     - Repository: `AuthRepository` (10 methods)
     - Use Cases: 7 use cases (login, logout, register, token refresh, password reset)

     **Presentation Layer** (✅ Complete):
     - `login_page.dart` - Beautiful auth UI with Google/Apple sign-in

     **Data Layer** (⚠️ Partial):
     - `data/services/auth_service.dart` - Handles JWT, Google/Apple auth

     ### 9. **Hours Approval Feature** (`features/hours_approval/`)
     **Purpose**: Review and approve staff hours worked at events

     **Presentation Layer** (✅ Exists):
     - `hours_approval_list_screen.dart`

     ---

     ## 🛠️ Technology Stack

     ### Core Technologies
     - **Flutter**: ^3.9.0 (Dart SDK)
     - **Architecture**: Clean Architecture + Feature-based modules
     - **State Management**: BLoC pattern (`flutter_bloc: ^8.1.6`)
     - **Dependency Injection**: GetIt + Injectable
     - **Immutability**: Freezed + Equatable
     - **Error Handling**: Dartz Either<Failure, T> pattern

     ### Key Dependencies

     | Package | Purpose | Usage |
     |---------|---------|-------|
     | `flutter_bloc` | State management | BLoCs for each feature |
     | `get_it` + `injectable` | DI container | Singleton services, repositories |
     | `freezed` | Immutable entities | All domain entities |
     | `equatable` | Value equality | Entity comparison |
     | `dartz` | Functional programming | Either<Failure, T> pattern |
     | `dio` | HTTP client | API communication |
     | `flutter_secure_storage` | Secure storage | JWT tokens, sensitive data |
     | `shared_preferences` | Key-value storage | Drafts, settings |
     | `file_picker` | File selection | PDF/image upload |
     | `image_picker` | Camera/gallery | Image capture |
     | `syncfusion_flutter_pdf` | PDF parsing | Extract text from PDFs |
     | `google_maps_flutter` | Maps integration | Event location display |
     | `google_places_flutter` | Address autocomplete | Venue address search |
     | `connectivity_plus` | Network status | Offline handling |
     | `logger` | Logging | Debug/production logs |
     | `google_sign_in` | Google auth | Authentication |
     | `sign_in_with_apple` | Apple auth | iOS authentication |
     | `url_launcher` | External links | Open maps, phone, email |
     | `intl` | Internationalization | Date/number formatting |

     ### Backend
     - **API**: Node.js/Express REST API
     - **Database**: MongoDB Atlas
     - **Base URL**: `https://api.nexapymesoft.com/api`
     - **Authentication**: JWT tokens (stored in FlutterSecureStorage)
     - **AI Extraction**: OpenAI API (GPT models)
     - **Sync Strategy**: Delta sync with Change Streams (90-95% data reduction)

     ---

     ## 📝 Development Patterns

     ### Adding a New Feature

     Follow this sequence:

     #### 1. Domain Layer (Pure Dart)
     ```dart
     // 1.1 Create entity (lib/features/{feature}/domain/entities/)
     @freezed
     class MyEntity with _$MyEntity implements Entity {
       const factory MyEntity({
         required String id,
         required String name,
         // ... fields
       }) = _MyEntity;
     }

     // 1.2 Define repository interface (lib/features/{feature}/domain/repositories/)
     abstract class MyRepository {
       Future<Either<Failure, List<MyEntity>>> getAll();
       Future<Either<Failure, MyEntity>> getById(String id);
       Future<Either<Failure, MyEntity>> create(MyEntity entity);
       // ... CRUD methods
     }

     // 1.3 Create use cases (lib/features/{feature}/domain/usecases/)
     class GetMyEntities extends UseCase<List<MyEntity>, NoParams> {
       final MyRepository repository;
       GetMyEntities(this.repository);

       @override
       Future<Either<Failure, List<MyEntity>>> call(NoParams params) {
         return repository.getAll();
       }
     }
     ```

     #### 2. Data Layer
     ```dart
     // 2.1 Create DTO model (lib/features/{feature}/data/models/)
     @freezed
     class MyEntityModel with _$MyEntityModel {
       const factory MyEntityModel({
         required String id,
         required String name,
         // ... fields
       }) = _MyEntityModel;

       factory MyEntityModel.fromJson(Map<String, dynamic> json) =>
           _$MyEntityModelFromJson(json);
     }

     // 2.2 Create mapper
     extension MyEntityMapper on MyEntityModel {
       MyEntity toEntity() => MyEntity(id: id, name: name);
     }

     // 2.3 Create remote data source (lib/features/{feature}/data/datasources/)
     abstract class MyRemoteDataSource {
       Future<List<MyEntityModel>> getAll();
     }

     class MyRemoteDataSourceImpl implements MyRemoteDataSource {
       final ApiClient client;
       MyRemoteDataSourceImpl(this.client);

       @override
       Future<List<MyEntityModel>> getAll() async {
         final response = await client.get(ApiEndpoints.myEntities);
         return (response.data as List)
             .map((json) => MyEntityModel.fromJson(json))
             .toList();
       }
     }

     // 2.4 Implement repository (lib/features/{feature}/data/repositories/)
     class MyRepositoryImpl implements MyRepository {
       final MyRemoteDataSource remoteDataSource;
       final NetworkInfo networkInfo;

       MyRepositoryImpl(this.remoteDataSource, this.networkInfo);

       @override
       Future<Either<Failure, List<MyEntity>>> getAll() async {
         if (!await networkInfo.isConnected) {
           return Left(NetworkFailure());
         }
         try {
           final models = await remoteDataSource.getAll();
           return Right(models.map((m) => m.toEntity()).toList());
         } on ServerException {
           return Left(ServerFailure());
         }
       }
     }
     ```

     #### 3. Presentation Layer
     ```dart
     // 3.1 Create BLoC (lib/features/{feature}/presentation/bloc/)
     class MyBloc extends Bloc<MyEvent, MyState> {
       final GetMyEntities getMyEntities;

       MyBloc(this.getMyEntities) : super(MyInitial()) {
         on<LoadMyEntities>(_onLoad);
       }

       Future<void> _onLoad(LoadMyEntities event, Emitter<MyState> emit) async {
         emit(MyLoading());
         final result = await getMyEntities(NoParams());
         result.fold(
           (failure) => emit(MyError(failure.message)),
           (entities) => emit(MyLoaded(entities)),
         );
       }
     }

     // 3.2 Create page (lib/features/{feature}/presentation/pages/)
     class MyPage extends StatelessWidget {
       @override
       Widget build(BuildContext context) {
         return BlocProvider(
           create: (_) => getIt<MyBloc>()..add(LoadMyEntities()),
           child: BlocBuilder<MyBloc, MyState>(
             builder: (context, state) {
               if (state is MyLoading) return LoadingWidget();
               if (state is MyError) return ErrorWidget(state.message);
               if (state is MyLoaded) return MyListWidget(state.entities);
               return Container();
             },
           ),
         );
       }
     }
     ```

     #### 4. Register with DI
     ```dart
     // In lib/core/di/injection.dart or feature module
     @module
     abstract class MyFeatureModule {
       @lazySingleton
       MyRemoteDataSource get remoteDataSource => MyRemoteDataSourceImpl(getIt());

       @LazySingleton(as: MyRepository)
       MyRepositoryImpl get repository => MyRepositoryImpl(getIt(), getIt());

       @lazySingleton
       GetMyEntities get getMyEntities => GetMyEntities(getIt());

       @injectable
       MyBloc get bloc => MyBloc(getIt());
     }
     ```

     ### Code Generation Commands

     Run after creating/modifying Freezed entities or Injectable classes:

     ```bash
     # Generate all (Freezed, JSON, Injectable)
     flutter pub run build_runner build --delete-conflicting-outputs

     # Watch mode (auto-regenerate on file changes)
     flutter pub run build_runner watch --delete-conflicting-outputs
     ```

     ### Error Handling Pattern

     Always use `Either<Failure, T>` from dartz:

     ```dart
     // Repository method
     Future<Either<Failure, Event>> getEvent(String id) async {
       try {
         if (!await networkInfo.isConnected) {
           return Left(NetworkFailure('No internet connection'));
         }

         final event = await remoteDataSource.getEvent(id);
         return Right(event.toEntity());
       } on ServerException catch (e) {
         return Left(ServerFailure(e.message));
       } on NotFoundException {
         return Left(NotFoundFailure('Event not found'));
       } catch (e) {
         return Left(UnknownFailure(e.toString()));
       }
     }

     // In BLoC or UI
     final result = await getEvent(eventId);
     result.fold(
       (failure) => showError(failure.message),  // Left side
       (event) => displayEvent(event),           // Right side
     );
     ```

     ---

     ## 🤖 AI Assistant Guidelines

     ### When Making Changes

     #### ✅ DO:
     - Follow the established Clean Architecture patterns
     - Use existing utilities (extensions, validators, formatters)
     - Check if a similar feature exists before creating new patterns
     - Use `Either<Failure, T>` for error handling
     - Use Freezed for entities/models
     - Add dartdoc comments to public APIs
     - Run code generation after creating Freezed/Injectable classes
     - Respect the feature module boundaries
     - Use dependency injection (never instantiate directly)
     - Check both new (domain) and legacy (services) code locations

     #### ❌ DON'T:
     - Mix layers (e.g., don't import data layer in domain)
     - Use `Map<String, dynamic>` in domain layer (use typed entities)
     - Ignore null safety
     - Make direct HTTP calls in presentation layer
     - Create god objects (split large classes)
     - Hardcode values (use constants)
     - Skip error handling
     - Modify generated files (*.freezed.dart, *.g.dart, *.config.dart)
     - Delete legacy services until migration is complete
     - Add sensitive data to version control (.env file)

     ### Code Location Quick Reference

     | Task | Location | Notes |
     |------|----------|-------|
     | Add validation | `core/utils/validators.dart` | Reuse existing or add new |
     | Format date/currency | `core/utils/formatters.dart` | Centralized formatters |
     | Add API endpoint | `core/config/api_endpoints.dart` | Constants with builders |
     | Add error message | `core/constants/error_messages.dart` | User-friendly messages |
     | Create entity | `features/{feature}/domain/entities/` | Use Freezed |
     | Define repository | `features/{feature}/domain/repositories/` | Interface only |
     | Create use case | `features/{feature}/domain/usecases/` | One per method |
     | Create DTO | `features/{feature}/data/models/` | JSON serializable |
     | Implement repo | `features/{feature}/data/repositories/` | With error handling |
     | Create BLoC | `features/{feature}/presentation/bloc/` | State management |
     | Create screen | `features/{feature}/presentation/pages/` | UI pages |
     | Shared widget | `shared/presentation/widgets/` | Reusable across features |
     | Theme colors | `shared/presentation/theme/app_colors.dart` | Material 3 palette |

     ### Migration Priority

     When refactoring legacy code, follow this order:

     1. **Events feature** (highest business value, most complex)
     2. **Users feature** (second most important)
     3. **Clients feature**
     4. **Roles & Tariffs features**
     5. **Extraction feature** (break down the 3,303-line screen)
     6. **Drafts feature**
     7. **Auth feature** (partially done)

     ### Common Pitfalls

     1. **Importing from wrong layer**: Domain should never import data/presentation
     2. **Skipping code generation**: Freezed classes won't work without running build_runner
     3. **Not checking legacy services**: Some functionality still lives in `features/extraction/services/`
     4. **Hardcoding API URLs**: Use `ApiEndpoints` class
     5. **Forgetting DI registration**: New classes need to be registered in GetIt
     6. **Ignoring delta sync**: Use `DeltaSyncService` for API calls (see `DELTA_SYNC_QUICKSTART.md`)

     ---

     ## 📊 Current State Summary

     ### ✅ What's Complete (Phase 1)
     - Core infrastructure (networking, DI, error handling, logging)
     - Theme system (Material 3, light/dark mode)
     - Domain layer for all 8 features (71 files)
     - 48 use cases covering all business logic
     - 180+ linting rules enforcing best practices
     - 100+ utility extensions (String, DateTime, BuildContext)
     - Delta sync system (90-95% data reduction)
     - Authentication UI (Google, Apple Sign-In)

     ### 🔜 What's In Progress (Phase 2)
     - Data layer implementation (models, data sources, repositories)
     - BLoC state management for all features
     - Breaking down monolithic extraction_screen.dart (3,303 lines)
     - Migrating legacy services to repository pattern

     ### ⚠️ Legacy Code (To Be Migrated)
     All services in `features/extraction/services/` are legacy:
     - `extraction_service.dart` - OpenAI integration
     - `event_service.dart` - Event CRUD
     - `clients_service.dart` - Client management
     - `users_service.dart` - User management
     - `roles_service.dart` - Role management
     - `tariffs_service.dart` - Tariff management
     - `draft_service.dart` - Local draft storage
     - `pending_events_service.dart` - Pending event management
     - `google_places_service.dart` - Address autocomplete

     **These services work but need to be migrated to the data layer following the repository pattern.**

     ---

     ## 🔐 Environment Variables

     Required in `.env` file (DO NOT commit):

     ```bash
     # OpenAI
     OPENAI_API_KEY=sk-proj-...

     # Backend API
     API_BASE_URL=https://api.nexapymesoft.com
     API_PATH_PREFIX=/api

     # Google Authentication
     GOOGLE_SERVER_CLIENT_ID=...
     GOOGLE_CLIENT_ID_ANDROID=...
     GOOGLE_CLIENT_ID_IOS=...
     GOOGLE_CLIENT_ID_WEB=...

     # Apple Authentication
     APPLE_BUNDLE_ID=com.example.nexa

     # Google Maps
     GOOGLE_MAPS_API_KEY=...
     GOOGLE_MAPS_IOS_SDK_KEY=...
     PLACES_BIAS_LAT=39.7392
     PLACES_BIAS_LNG=-104.9903
     PLACES_COMPONENTS=country:us
     ```

     Access via:
     ```dart
     Environment.apiBaseUrl
     Environment.openAiApiKey
     // etc.
     ```

     ---

     ## 🧪 Testing Strategy

     ### Test Structure (Not Yet Implemented)
     ```
     test/
     ├── unit/
     │   ├── domain/
     │   │   ├── entities/        # Entity method tests
     │   │   └── usecases/        # Use case logic tests
     │   ├── data/
     │   │   ├── models/          # JSON serialization tests
     │   │   └── repositories/    # Repository implementation tests
     │   └── utils/               # Validator/formatter tests
     ├── widget/
     │   └── presentation/        # Widget tests
     └── integration/             # Full feature flow tests
     ```

     ### Testing Tools Available
     - `mockito` - Mocking
     - `bloc_test` - BLoC testing
     - `mocktail` - Alternative mocking

     ---

     ## 🎨 UI/UX Notes

     ### Theme
     - Material 3 design system
     - Primary color: Indigo (#6366F1)
     - Secondary color: Purple (#430172)
     - Dark mode support
     - Custom shadows, dimensions, text styles

     ### Key Screens
     - **Login** (`features/auth/presentation/pages/login_page.dart`) - Beautiful gradient auth UI
     - **Extraction Screen** (`features/extraction/presentation/extraction_screen.dart`) - Main hub (needs refactoring)
     - **Pending Publish** - Review AI-extracted events
     - **User Events** - Staff member's event schedule
     - **Manager Profile** - Profile management

     ### Responsive Design
     - Mobile-first (portrait orientation enforced)
     - Web support (with refresh buttons for web-specific behavior)
     - Max width constraints for large screens

     ---

     ## 📚 Related Documentation

     - **`REFACTORING_SUMMARY.md`** - Detailed Phase 1 completion report
     - **`DELTA_SYNC_QUICKSTART.md`** - Delta sync implementation guide
     - **`lib/core/sync/README.md`** - Delta sync service usage
     - **`shared/presentation/theme/README.md`** - Theme system guide

     ---

     ## 🚀 Quick Start for AI Assistants

     ### Understanding the Project
     1. Read this file (AI_CONTEXT.md)
     2. Check current phase status in REFACTORING_SUMMARY.md
     3. Look at domain entities to understand business model
     4. Review extraction_screen.dart to see current UI state

     ### Making Changes
     1. **Identify the feature**: events, clients, users, etc.
     2. **Check layer**: domain (complete) vs data (in progress) vs presentation (mixed)
     3. **Follow patterns**: Look at similar existing code
     4. **Use utilities**: Check core/utils before creating new helpers
     5. **Generate code**: Run build_runner after Freezed/Injectable changes
     6. **Test locally**: Ensure no breaking changes to existing functionality

     ### Common Tasks
     - **Add API endpoint**: `core/config/api_endpoints.dart`
     - **Add validation**: `core/utils/validators.dart`
     - **Add formatter**: `core/utils/formatters.dart`
     - **Create entity**: `features/{feature}/domain/entities/{entity}.dart` + run build_runner
     - **Add use case**: `features/{feature}/domain/usecases/{action}_{entity}.dart`
     - **Fix UI**: Look in `features/{feature}/presentation/` or legacy `extraction_screen.dart`

     ---

     **Last Updated**: 2025-01-15
     **Maintainer**: Development Team
     **For Questions**: Refer to inline dartdoc comments or ask the development team
