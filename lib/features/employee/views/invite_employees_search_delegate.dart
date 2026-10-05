import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:stark/theme/stark_icons.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:stark/features/employee/controllers/employee_controller.dart';
import 'package:stark/features/employee/widgets/invite_employee_tile.dart';
import 'package:stark/utils/error_text.dart';
import 'package:stark/utils/loader.dart';

class InviteEmployeesSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  InviteEmployeesSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(StarkIcons.x),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: "Back",
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final user = ref.watch(userProvider)!;
    return ref
        .watch(searchEmployeeToInviteProvider(query))
        .when(
          data: (employees) => employees.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No employees found. Employees need an account before they can be invited.',
                    ),
                  ),
                )
              :
                //  employees.isEmpty
                //     ? ErrorText(error: 'No user found with this email')
                //     :
                ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                  ).copyWith(top: 20.h),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    if (employee.uid == user.uid) {
                      return const SizedBox.shrink();
                    }
                    if (employee.isAdmin == true) {
                      return const SizedBox.shrink();
                    }
                    return InviteEmployeeTile(
                      uid: employee.uid,
                      name: '${employee.firstName} ${employee.lastName}',
                      email: employee.email,
                      status: '',
                      profilePic: employee.profilePic,
                      onTap: () {},
                    );
                    //  ListTile(
                    //   leading: CircleAvatar(
                    //     backgroundImage: NetworkImage(employee.profilePic),
                    //   ),
                    //   title: Text(employee.email),
                    //   // onTap: () => navigateToCommunity(context, community.name),
                    // );
                  },
                ),
          error: (error, stackTrace) => ErrorText(error: error.toString()),
          loading: () => const Loader(),
        );
  }
}
