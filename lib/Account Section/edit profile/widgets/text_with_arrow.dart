import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants.dart';

class TextWithArrow extends StatelessWidget {
  const TextWithArrow({
    super.key,
    required this.text,
    this.showArrow = true,
  });

  final String text;
  final bool showArrow;

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min, // Important: Don't take more space than needed
      children: [
        Flexible(
          // Use Flexible instead of Expanded for the text
          child: Text(
            _truncateText(text, 100),
            overflow: TextOverflow.ellipsis,
            maxLines: 1, // Changed to 1 line for profile tiles
            style: TextStyle(
              fontSize: 14.sp,
              color: kLighterText2Color,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        if (showArrow) ...[
          SizedBox(
            width: 10.w,
          ),
          SvgPicture.asset(
            'assets/icons/ic-arrow-right.svg',
          ),
        ]
      ],
    );
  }
}
