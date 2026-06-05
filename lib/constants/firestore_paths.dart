class FirestorePaths {
  FirestorePaths._();

  static const String users = 'users';
  static const String media = 'media';

  static String userMedia(String userId) => '$users/$userId/$media';

  static String mediaDoc(String userId, String mediaId) =>
      '$users/$userId/$media/$mediaId';
}
