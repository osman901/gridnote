// lib/widgets/value_listenable_builder_2.dart
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget? child;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, a, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, __) => builder(context, a, b, child),
          child: child,
        );
      },
      child: child,
    );
  }
}
