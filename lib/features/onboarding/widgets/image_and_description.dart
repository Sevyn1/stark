import 'package:flutter/material.dart';

class ImageAndDescription extends StatelessWidget {
  final String image;
  final double textSpace;
  final String text;
  final FontWeight? fontWeight;
  final double? fontSize;
  final Color? color;
  const ImageAndDescription(
      {super.key,
      required this.image,
      required this.text,
      required this.textSpace,
      this.fontWeight,
      this.fontSize,
      this.color});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final size = MediaQuery.of(context).size;
    return Column(children: [
      Image.asset(image),
      SizedBox(
        height: textSpace,
      ),
      SizedBox(
        width: size.height * 0.3,
        child: Text(
          text,
          style: TextStyle(
              fontWeight: fontWeight ?? FontWeight.w500,
              fontSize: fontSize ?? 15,
              color: color ?? const Color.fromRGBO(74, 70, 70, 1),
              fontStyle: FontStyle.normal),
          textAlign: TextAlign.center,
        ),
      )
    ]);
  }
}
