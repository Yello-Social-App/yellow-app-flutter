import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/notification_preferences_entity.dart';
import '../../domain/usecases/notification_usecases.dart';

enum PreferencesStatus { initial, loading, loaded, error }

class NotificationPreferencesState extends Equatable {
  const NotificationPreferencesState({
    this.status = PreferencesStatus.initial,
    this.preferences = NotificationPreferencesEntity.defaults,
    this.errorMessage,

    /// Type currently mid-save (its row shows a small inline spinner
    /// instead of the toggle) — `null`/`'*'` sentinel not needed since only
    /// one row is ever mutating at a time from this screen.
    this.savingKey,
  });

  final PreferencesStatus status;
  final NotificationPreferencesEntity preferences;
  final String? errorMessage;
  final String? savingKey;

  NotificationPreferencesState copyWith({
    PreferencesStatus? status,
    NotificationPreferencesEntity? preferences,
    String? errorMessage,
    String? savingKey,
  }) {
    return NotificationPreferencesState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      errorMessage: errorMessage,
      savingKey: savingKey,
    );
  }

  @override
  List<Object?> get props => [status, preferences, errorMessage, savingKey];
}

/// Backs the notification-settings screen (`GET`/`PUT
/// /notifications/v1/preferences`). A fresh cubit per screen visit — this
/// tab has no reason to survive a pop, unlike the always-mounted
/// `NotificationsCubit`.
class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  NotificationPreferencesCubit({
    required GetNotificationPreferencesUseCase getPreferences,
    required UpdateNotificationPreferencesUseCase updatePreferences,
  }) : _getPreferences = getPreferences,
       _updatePreferences = updatePreferences,
       super(const NotificationPreferencesState());

  final GetNotificationPreferencesUseCase _getPreferences;
  final UpdateNotificationPreferencesUseCase _updatePreferences;

  Future<void> load() async {
    emit(state.copyWith(status: PreferencesStatus.loading));
    final result = await _getPreferences(const NoParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: PreferencesStatus.error, errorMessage: failure.message)),
      (preferences) => emit(state.copyWith(status: PreferencesStatus.loaded, preferences: preferences)),
    );
  }

  Future<void> setPushEnabled(bool enabled) => _save(state.preferences.copyWith(pushEnabled: enabled), savingKey: 'push');

  Future<void> toggleMuted(String type) {
    final muted = {...state.preferences.mutedTypes};
    if (!muted.remove(type)) muted.add(type);
    return _save(state.preferences.copyWith(mutedTypes: muted.toList()..sort()), savingKey: type);
  }

  /// `PUT` replaces the whole record — every call sends the full current
  /// state, never just the one field that changed (an omitted field would
  /// reset to its default). Optimistic: flips immediately, reverts on
  /// failure.
  Future<void> _save(NotificationPreferencesEntity next, {required String savingKey}) async {
    final previous = state.preferences;
    emit(state.copyWith(preferences: next, savingKey: savingKey));
    final result = await _updatePreferences(
      UpdateNotificationPreferencesParams(pushEnabled: next.pushEnabled, mutedTypes: next.mutedTypes),
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(preferences: previous, savingKey: null, errorMessage: failure.message),
      ),
      (saved) => emit(state.copyWith(preferences: saved, savingKey: null)),
    );
  }
}
