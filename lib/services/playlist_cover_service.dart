import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PlaylistCoverService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickAndStore() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600, maxHeight: 1600);
    if (picked == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory('${directory.path}/playlist_covers');
    if (!await folder.exists()) await folder.create(recursive: true);
    final extension = picked.name.contains('.') ? picked.name.substring(picked.name.lastIndexOf('.')) : '.jpg';
    final file = File('${folder.path}/${DateTime.now().microsecondsSinceEpoch}$extension');
    await File(picked.path).copy(file.path);
    return file.path;
  }
}
