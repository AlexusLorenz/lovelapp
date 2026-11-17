import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../data/demo_data.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView(
        children: [
          for (final match in demoMatches)
            ListTile(
              leading: CircleAvatar(
                child: Text(match.profile.name.characters.first),
              ),
              title: Text(match.profile.name),
              subtitle: Text(
                match.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => context.go(Routes.chat(match.id)),
            ),
        ],
      ),
    );
  }
}
