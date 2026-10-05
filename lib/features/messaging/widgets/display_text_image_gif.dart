import 'package:flutter/material.dart';
import 'package:stark/core/enums/enums.dart';

class DisplayTextImageGIF extends StatelessWidget {
  final String message;
  final MessageEnum type;
  const DisplayTextImageGIF(
      {super.key, required this.message, required this.type});
  @override
  Widget build(BuildContext context) => type == MessageEnum.image
      ? ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
          child: Image.network(message,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('Image unavailable',
                  style: TextStyle(color: Colors.white))))
      : Text(message,
          style: const TextStyle(fontSize: 16, color: Colors.white));
}
