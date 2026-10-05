import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const localDemo = bool.fromEnvironment('LOCAL_DEMO');
const demoAppName = 'stark-local-demo';
FirebaseApp get firebaseApp => Firebase.app(localDemo ? demoAppName : '[DEFAULT]');
FirebaseAuth get authService => FirebaseAuth.instanceFor(app: firebaseApp);
FirebaseFirestore get firestoreService => FirebaseFirestore.instanceFor(app: firebaseApp);
FirebaseStorage get storageService => FirebaseStorage.instanceFor(app: firebaseApp);
final firestoreProvider = Provider((ref) => firestoreService);
final authProvider = Provider((ref) => authService);
final storageProvider = Provider((ref) => storageService);
