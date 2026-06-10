import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

String profileSectionCount(int count) =>
    count.toString().padLeft(2, '0');

class ProfileSectionDivider extends StatelessWidget {
  const ProfileSectionDivider({
    super.key,
    required this.tag,
    required this.count,
  });

  final String tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 1,
          color: KeepiColors.slate.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        Text(
          tag,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: KeepiColors.slate,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: KeepiColors.slateSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            profileSectionCount(count),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: 0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: KeepiColors.slate.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class ProfileHeroCard extends StatelessWidget {
  const ProfileHeroCard({
    super.key,
    required this.name,
    required this.email,
    this.namePrefix = 'Dr.',
  });

  final String name;
  final String email;
  final String namePrefix;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final displayName = namePrefix.isEmpty ? name : '$namePrefix $name';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 2, color: KeepiColors.slate),
            const SizedBox(width: 8),
            const Text(
              'CUENTA',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: KeepiColors.orange, width: 1.6),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isEmpty ? 'Correo no disponible' : email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KeepiColors.slateLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileSettingsRow extends StatelessWidget {
  const ProfileSettingsRow({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isActive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isActive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? KeepiColors.orange : KeepiColors.cardBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? KeepiColors.orangeSoft.withValues(alpha: 0.65)
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? KeepiColors.orange : accent,
                    width: 1.6,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isActive ? KeepiColors.orange : accent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KeepiColors.slateLight,
                        height: 1.3,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Activo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.orange,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron && enabled && !isActive)
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: KeepiColors.slate,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
