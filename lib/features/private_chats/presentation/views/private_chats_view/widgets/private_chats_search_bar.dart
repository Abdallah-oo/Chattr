import 'package:chattr/core/cubits/search/search_cubit.dart';
import 'package:chattr/core/themes/app_colors.dart';
import 'package:chattr/core/widgets/custom_text_field.dart';
import 'package:chattr/features/private_chats/data/models/private_chat_model.dart';
import 'package:chattr/features/private_chats/presentation/cubits/fetch_private_chats_cubit/fetch_private_chats_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


class ChatSearchBar extends StatefulWidget {
  const ChatSearchBar({super.key});

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    _searchController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchPrivateChatsCubit, FetchPrivateChatsState>(
      builder: (context, state) {
         List<PrivateChatModel>chats=[];
       if(state is FetchPrivateChatsSuccess){
          chats=state.chats;
       }
        
        return chats.isNotEmpty?
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: CustomTextField(
            controller: _searchController,
            hint: "search",
            validation: (v) {
              return null;
            },
            onChange: (value) => context.read<SearchCubit>().search(list: chats, query: value, searchBy: (item) => item.name,),
    
            suffixIcon: Icon(CupertinoIcons.search, color: AppColors.inputBorder),
          ),
        ):SizedBox.shrink();
      },
    );
  }
}
