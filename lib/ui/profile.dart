import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import 'components.dart';
import 'theme.dart';

/// Round emoji avatar on a pastel colour. Used for you and your barkada.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.emoji, required this.color, this.size = 44, this.ring = false});
  final String emoji;
  final int color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(kAvatarColors[color.clamp(0, kAvatarColors.length - 1)]),
          shape: BoxShape.circle,
          border: ring ? Border.all(color: T.ink, width: 2) : null,
        ),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5, height: 1.1)),
      );
}

/// Your avatar, tappable to edit your profile.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return Semantics(
      button: true,
      label: 'Edit profile',
      child: InkResponse(
        radius: size * 0.7,
        onTap: () => showProfileSheet(context),
        child: Stack(clipBehavior: Clip.none, children: [
          Avatar(emoji: s.avatar, color: s.avatarColor, size: size),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: T.ink, shape: BoxShape.circle, border: Border.all(color: T.cream, width: 2)),
              child: const Icon(Icons.edit, size: 11, color: T.lime),
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> showProfileSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const _ProfileSheet(),
    );

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  final s = AppState.I;
  late final name = TextEditingController(text: s.name);
  late String emoji = s.avatar;
  late int color = s.avatarColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 14, 22, MediaQuery.of(context).viewInsets.bottom + 22),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: T.line, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          Row(children: [
            Avatar(emoji: emoji, color: color, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your profile', style: T.h(22)),
                Text('Makikita ito sa barkada card mo. Stays on this phone.', style: T.b(13, color: T.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            style: T.b(17, w: FontWeight.w600),
            decoration: const InputDecoration(labelText: 'Pangalan', counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('AVATAR', style: T.kicker(color: T.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kAvatarEmojis)
              GestureDetector(
                onTap: () => setState(() => emoji = e),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e == emoji ? T.oliveSoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: e == emoji ? T.olive : T.line, width: e == emoji ? 2 : 1),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Text('KULAY', style: T.kicker(color: T.muted)),
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 0; i < kAvatarColors.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Semantics(
                  button: true,
                  label: 'Color ${i + 1}',
                  child: GestureDetector(
                    onTap: () => setState(() => color = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(kAvatarColors[i]),
                        shape: BoxShape.circle,
                        border: Border.all(color: i == color ? T.ink : Colors.transparent, width: 3),
                      ),
                      child: i == color ? const Icon(Icons.check, color: T.ink, size: 20) : null,
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 22),
          PrimaryButton('I-save', icon: Icons.check, onTap: () async {
            final nav = Navigator.of(context);
            await s.setProfile(name.text, emoji, color);
            nav.pop();
          }),
        ]),
      ),
    );
  }
}
