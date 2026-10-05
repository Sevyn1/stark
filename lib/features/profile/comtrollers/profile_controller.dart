import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stark/core/providers/storage_repository_provider.dart';
import 'package:stark/features/auth/controllers/auth_controller.dart';
import 'package:stark/utils/snack_bar.dart';
import '../repositories/profile_repository.dart';

final userProfileControllerProvider=StateNotifierProvider<UserProfileController,bool>((ref)=>UserProfileController(
  userProfileRepository:ref.watch(userProfileRepositoryProvider),storageRepository:ref.watch(storageRepositoryProvider),ref:ref));
class UserProfileController extends StateNotifier<bool>{
  final UserProfileRepository _userProfileRepository;
  final StorageRepository _storageRepository;
  final Ref _ref;
  UserProfileController({required UserProfileRepository userProfileRepository,required StorageRepository storageRepository,required Ref ref})
    :_userProfileRepository=userProfileRepository,_storageRepository=storageRepository,_ref=ref,super(false);
  Future<bool> editUserProfile({required BuildContext context,File? profileFile,Uint8List? profileBytes,
      required String firstName,required String lastName,required String role,required String phone})async{
    state=true;
    try{
      final user=_ref.read(userProvider)!;
      var photo=user.profilePic;
      if(profileFile!=null||profileBytes!=null){
        final upload=await _storageRepository.storeFile(path:'profiles',id:user.uid,file:profileFile,webFile:profileBytes);
        String? failure;
        upload.fold((f)=>failure=f.message,(url)=>photo=url);
        if(failure!=null){if(context.mounted) showSnackBar(context,failure!);return false;}
      }
      final updated=user.copyWith(firstName:firstName.trim(),lastName:lastName.trim(),role:role.trim(),phone:phone.trim(),profilePic:photo);
      final result=await _userProfileRepository.editProfile(updated);
      return result.fold((failure){if(context.mounted) showSnackBar(context,failure.message);return false;},(_){
        _ref.read(userProvider.notifier).state=updated;
        if(context.mounted) showSnackBar(context,'Profile saved.');return true;
      });
    }finally{if(mounted) state=false;}
  }
}
