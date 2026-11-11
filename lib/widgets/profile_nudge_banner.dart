import 'package:flutter/material.dart';

/// 프로필 설정을 안내하는 공통 배너.
class ProfileNudgeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const ProfileNudgeBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_outlined, color: Colors.deepOrange, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '프로필을 설정하면 칼로리 기준이 맞춤 설정돼요',
                style: TextStyle(color: Colors.deepOrange, fontSize: 12, height: 1.4),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.deepOrange, size: 16),
          ],
        ),
      ),
    );
  }
}
