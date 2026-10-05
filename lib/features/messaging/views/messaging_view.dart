import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:stark/features/messaging/controllers/messaging_controller.dart';
import 'package:stark/features/messaging/widgets/bottom_chat_field.dart';
import 'package:stark/features/messaging/widgets/messages_list_view.dart';
import 'package:stark/theme/palette.dart';
import 'package:stark/utils/app_bar.dart';
import 'package:stark/utils/error_text.dart';
import 'package:stark/utils/loader.dart';

class MessagingView extends ConsumerWidget {
  const MessagingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(userProvider)?.organisation.isEmpty ?? true) return const Scaffold(appBar: MyAppBar(title: 'Messages'), body: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Accept an invitation to join your team’s conversations.'))));
    final messagesStream = ref.watch(getGroupChatStreamProvider);
    return Scaffold(
      appBar: const MyAppBar(
        title: 'Messages',
      ),
      body: messagesStream.when(
        data: (data) {
          return Column(
            children: const [
              Expanded(
                child: MessagesListView(),
              ),
              BottomChatField(),
            ],
          );
        },
        error: (_, __) => Center(child: Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Could not load messages. Please try again.'),
          TextButton(onPressed:()=>ref.invalidate(getGroupChatStreamProvider),child:const Text('Retry')),
        ])),
        loading: () => const Loader(),
      ),
    );
  }
}
