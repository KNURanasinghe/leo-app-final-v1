// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:video_player/video_player.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:path/path.dart' as path;
// import 'package:http_parser/http_parser.dart';

// class AddStatusScreen extends StatefulWidget {
//   const AddStatusScreen({Key? key}) : super(key: key);

//   @override
//   State<AddStatusScreen> createState() => _AddStatusScreenState();
// }

// class _AddStatusScreenState extends State<AddStatusScreen> {
//   final TextEditingController _captionController = TextEditingController();
//   final ImagePicker _picker = ImagePicker();
//   File? _mediaFile;
//   bool _isVideo = false;
//   bool _isLoading = false;
//   VideoPlayerController? _videoController;

//   @override
//   void dispose() {
//     _captionController.dispose();
//     _videoController?.dispose();
//     super.dispose();
//   }

//   Future<void> _pickMedia(ImageSource source) async {
//     try {
//       // Show dialog to choose between image and video
//       final bool? isVideo = await showDialog<bool>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: const Text('Choose Media Type'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.image),
//                 title: const Text('Image'),
//                 onTap: () => Navigator.pop(context, false),
//               ),
//               ListTile(
//                 leading: const Icon(Icons.video_camera_back),
//                 title: const Text('Video'),
//                 onTap: () => Navigator.pop(context, true),
//               ),
//             ],
//           ),
//         ),
//       );

//       if (isVideo == null) return;

//       final XFile? pickedFile = isVideo
//           ? await _picker.pickVideo(source: source)
//           : await _picker.pickImage(source: source);

//       if (pickedFile != null) {
//         setState(() {
//           _mediaFile = File(pickedFile.path);
//           _isVideo = isVideo;
//         });

//         if (isVideo) {
//           _videoController = VideoPlayerController.file(_mediaFile!)
//             ..initialize().then((_) {
//               setState(() {});
//               _videoController!.play();
//               _videoController!.setLooping(true);
//             });
//         }
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error picking media: $e')),
//       );
//     }
//   }

//   Future<void> _uploadStatus() async {
//     if (_mediaFile == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select an image or video')),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final userId = prefs.getString('userId') ?? '';

//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse('http://145.223.21.62:8090/api/collections/Status/records'),
//       );

//       // Add text fields
//       request.fields['userId'] = userId;
//       request.fields['caption'] = _captionController.text;

//       // Add media file
//       final fileExtension = path.extension(_mediaFile!.path).toLowerCase();
//       final isImage = ['.jpg', '.jpeg', '.png', '.gif'].contains(fileExtension);

//       request.files.add(
//         await http.MultipartFile.fromPath(
//           isImage ? 'status_img' : 'status_video',
//           _mediaFile!.path,
//           contentType: MediaType(
//             isImage ? 'image' : 'video',
//             fileExtension.substring(1),
//           ),
//         ),
//       );

//       final response = await request.send();

//       if (response.statusCode == 200) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Status uploaded successfully!')),
//           );
//           Navigator.pop(context, true);
//         }
//       } else {
//         throw Exception('Failed to upload status');
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error uploading status: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: const Text('New Status'),
//         actions: [
//           if (_mediaFile != null)
//             TextButton(
//               onPressed: _isLoading ? null : _uploadStatus,
//               child: _isLoading
//                   ? const SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 ),
//               )
//                   : const Text(
//                 'Share',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: _mediaFile == null
//                 ? _buildMediaPickerPlaceholder()
//                 : _isVideo
//                 ? _buildVideoPreview()
//                 : _buildImagePreview(),
//           ),
//           _buildBottomSection(),
//         ],
//       ),
//     );
//   }

//   Widget _buildMediaPickerPlaceholder() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const Icon(
//             Icons.add_photo_alternate,
//             size: 100,
//             color: Colors.white54,
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'Add Photo or Video',
//             style: TextStyle(
//               color: Colors.white54,
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 32),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               _buildPickerButton(
//                 'Camera',
//                 Icons.camera_alt,
//                     () => _pickMedia(ImageSource.camera),
//               ),
//               const SizedBox(width: 32),
//               _buildPickerButton(
//                 'Gallery',
//                 Icons.photo_library,
//                     () => _pickMedia(ImageSource.gallery),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPickerButton(String label, IconData icon, VoidCallback onTap) {
//     return InkWell(
//       onTap: onTap,
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.blue[700],
//               shape: BoxShape.circle,
//             ),
//             child: Icon(icon, color: Colors.white, size: 30),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             label,
//             style: const TextStyle(color: Colors.white54),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoPreview() {
//     if (_videoController?.value.isInitialized ?? false) {
//       return Stack(
//         alignment: Alignment.center,
//         children: [
//           AspectRatio(
//             aspectRatio: _videoController!.value.aspectRatio,
//             child: VideoPlayer(_videoController!),
//           ),
//           IconButton(
//             icon: Icon(
//               _videoController!.value.isPlaying
//                   ? Icons.pause_circle_outlined
//                   : Icons.play_circle_outline,
//               size: 50,
//               color: Colors.white.withOpacity(0.7),
//             ),
//             onPressed: () {
//               setState(() {
//                 _videoController!.value.isPlaying
//                     ? _videoController!.pause()
//                     : _videoController!.play();
//               });
//             },
//           ),
//         ],
//       );
//     } else {
//       return const Center(child: CircularProgressIndicator());
//     }
//   }

//   Widget _buildImagePreview() {
//     return Image.file(
//       _mediaFile!,
//       fit: BoxFit.contain,
//     );
//   }

//   Widget _buildBottomSection() {
//     return Container(
//       color: Colors.black87,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: SafeArea(
//         child: Column(
//           children: [
//             TextField(
//               controller: _captionController,
//               style: const TextStyle(color: Colors.white),
//               maxLines: 3,
//               minLines: 1,
//               decoration: const InputDecoration(
//                 hintText: 'Add a caption...',
//                 hintStyle: TextStyle(color: Colors.white54),
//                 border: InputBorder.none,
//               ),
//             ),
//             if (_mediaFile != null) ...[
//               const Divider(color: Colors.white24),
//               Row(
//                 children: [
//                   TextButton.icon(
//                     onPressed: () => _pickMedia(ImageSource.gallery),
//                     icon: const Icon(Icons.photo_library),
//                     label: const Text('Change Media'),
//                     style: TextButton.styleFrom(
//                       foregroundColor: Colors.white54,
//                     ),
//                   ),
//                   const Spacer(),
//                   TextButton.icon(
//                     onPressed: () {
//                       setState(() {
//                         _mediaFile = null;
//                         _videoController?.dispose();
//                         _videoController = null;
//                       });
//                     },
//                     icon: const Icon(Icons.delete),
//                     label: const Text('Remove'),
//                     style: TextButton.styleFrom(
//                       foregroundColor: Colors.red,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }