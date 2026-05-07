enum AvdState { stopped, starting, booting, running, stopping }

extension AvdStateX on AvdState {
  String get label {
    switch (this) {
      case AvdState.stopped:
        return 'Stopped';
      case AvdState.starting:
        return 'Starting';
      case AvdState.booting:
        return 'Booting';
      case AvdState.running:
        return 'Running';
      case AvdState.stopping:
        return 'Stopping';
    }
  }

  bool get isTransitioning =>
      this == AvdState.starting ||
      this == AvdState.booting ||
      this == AvdState.stopping;

  bool get editable => this == AvdState.stopped;
}
