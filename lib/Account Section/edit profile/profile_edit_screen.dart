import 'dart:convert';
import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'theme.dart';
import '../constants.dart';
import 'widgets/body_container.dart';
import 'widgets/gender_selector_dialog.dart';
import 'widgets/back_button.dart';
import 'widgets/profile_edit_tile.dart';
import 'widgets/text_with_arrow.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String firstname;
  const EditProfileScreen(
      {super.key, required this.firstname, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  DateTime selectedDate = DateTime.now();
  final picker = ImagePicker();
  XFile? file;
  Country? selectedCountry;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      final response = await http.get(Uri.parse(
          'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'));

      if (response.statusCode == 200) {
        setState(() {
          userData = json.decode(response.body);
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> selectDate(BuildContext context) async {
    DateTime initialDate;

    // Check if the birthday is available
    if (userData?['birthday'] != null && userData!['birthday'].isNotEmpty) {
      try {
        initialDate = DateTime.parse(userData!['birthday']);
      } catch (e) {
        print('Date parse error: $e');
        initialDate = DateTime.now(); // Fallback to current date
      }
    } else {
      // If birthday is not available, set a default date
      initialDate = DateTime.now(); // or any other default date
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      updateBirthday(picked);
    }
  }

  Future<void> updateBirthday(DateTime birthday) async {
    try {
      final response = await http.patch(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'birthday': birthday.toUtc().toIso8601String()}),
      );

      if (response.statusCode == 200) {
        fetchUserData(); // Refresh UI
      }
    } catch (e) {
      print('Error updating birthday: $e');
    }
  }

  Future<void> pickAndUploadImage({bool isCoverPhoto = false}) async {
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        final ext = extension(pickedFile.path);
        var request = http.MultipartRequest(
          'PATCH',
          Uri.parse(
              'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
        );

        request.files.add(http.MultipartFile.fromBytes(
          isCoverPhoto
              ? 'coverphoto'
              : 'avatar', // Determine field name based on type
          bytes,
          filename: 'coverphoto$ext',
        ));

        final response = await request.send();
        if (response.statusCode == 200) {
          fetchUserData(); // Refresh UI
        }
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  // Future<void> selectDate(BuildContext context) async {
  //   DateTime initialDate;
  //   if (userData?['birthday'] != null) {
  //     try {
  //       // Handle Pocketbase's datetime format
  //       initialDate = DateTime.parse(userData!['birthday']);
  //     } catch (e) {
  //       initialDate = DateTime.now();
  //       print('Date parse error: $e');
  //     }
  //   } else {
  //     initialDate = DateTime.now();
  //   }
  //
  //   final DateTime? picked = await showDatePicker(
  //     context: context,
  //     initialDate: initialDate,
  //     firstDate: DateTime(1900),
  //     lastDate: DateTime.now(),
  //   );
  //
  //   if (picked != null) {
  //     updateBirthday(picked);
  //   }
  // }

  // Future<void> updateBirthday(DateTime birthday) async {
  //   try {
  //     final response = await http.patch(
  //       Uri.parse('http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'birthday': birthday.toUtc().toIso8601String(),
  //       }),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       fetchUserData();
  //     }
  //   } catch (e) {
  //     print('Error updating birthday: $e');
  //   }
  // }

  // Future<void> pickAndUploadImage() async {
  //   try {
  //     final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  //
  //     if (pickedFile != null) {
  //       final bytes = await File(pickedFile.path).readAsBytes();
  //       final ext = extension(pickedFile.path);
  //
  //       var request = http.MultipartRequest(
  //           'PATCH',
  //           Uri.parse('http://145.223.21.62:8090/api/collections/users/records/${widget.userId}')
  //       );
  //
  //       request.files.add(
  //           http.MultipartFile.fromBytes(
  //               'avatar',
  //               bytes,
  //               filename: 'avatar$ext'
  //           )
  //       );
  //
  //       final response = await request.send();
  //       if (response.statusCode == 200) {
  //         fetchUserData(); // Refresh UI
  //       }
  //     }
  //   } catch (e) {
  //     print('Error uploading image: $e');
  //   }
  // }

  Future<void> _saveCountryToDatabase(Country country) async {
    try {
      final response = await http.patch(
        Uri.parse(
            'http://145.223.21.62:8090/api/collections/users/records/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'country': country.name,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          selectedCountry = country;
        });
      }
    } catch (e) {
      print('Error updating country: $e');
    }
  }

  Future<String> getuserId() async {
    return "";
  }

  String _formatIdToInteger(String userId) {
    int? intId;
    String displayId = 'N/A';

    try {
      if (userId.isNotEmpty) {
        intId = int.parse(userId, radix: 36);
        displayId = intId.toString();
        print('Converted ID: $intId');
      }
    } catch (e) {
      print('Error converting ID to integer: $e');
      // Fallback: use hash code or show original ID
      try {
        intId = userId.hashCode.abs();
        displayId = intId.toString();
      } catch (e2) {
        displayId = userId; // Show original ID as fallback
      }
    }

    return displayId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // leading: const AppBarBackButton(),
        centerTitle: true,
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 16.sp,
            color: darkModeEnabled ? kDarkTextColor : kTextColor,
          ),
        ),
      ),
      body: BodyContainer(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Material(
                color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
                borderRadius: BorderRadius.circular(10.w),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20.0, horizontal: 10.0),
                  child: Column(
                    children: [
                      ProfileEditTile(
                        icon: 'assets/icons/ic-user.svg',
                        text: 'Avatar',
                        onTap: () =>
                            pickAndUploadImage(), // Call the method to pick and upload image
                        endWidget: ClipRRect(
                          borderRadius: BorderRadius.circular(10.w),
                          child: userData?.containsKey('avatar') ??
                                  false && userData!['avatar'] != null
                              ? Image.network(
                                  'http://145.223.21.62:8090/api/files/${userData!['collectionId']}/${userData!['id']}/${userData!['avatar']}',
                                  width: 35.w, // Set a fixed width
                                  height: 35.w, // Set a fixed height
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Handle image loading error
                                    return Container(
                                      width: 35.w,
                                      height: 35.w,
                                      decoration: BoxDecoration(
                                        color: Colors
                                            .grey[300], // Placeholder color
                                        borderRadius:
                                            BorderRadius.circular(10.w),
                                      ),
                                      child: const Icon(Icons.error,
                                          color: Colors
                                              .red), // Optional error icon
                                    );
                                  },
                                )
                              : Container(
                                  width: 35.w, // Set a fixed width
                                  height: 35.w, // Set a fixed height
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.grey[300], // Placeholder color
                                    borderRadius: BorderRadius.circular(10.w),
                                  ),
                                  child: const Icon(Icons.image,
                                      color: Colors.grey), // Placeholder icon
                                ),
                        ),
                      ),
                      const Divider(
                        color: kSeperatorColor,
                        indent: 20.0,
                        endIndent: 20.0,
                      ),
                      ProfileEditTile(
                        icon:
                            'assets/icons/ic-image.svg', // Use appropriate icon
                        text: 'Cover Photo',
                        onTap: () => pickAndUploadImage(isCoverPhoto: true),
                        endWidget: ClipRRect(
                          borderRadius: BorderRadius.circular(10.w),
                          child: userData?.containsKey('coverphoto') ??
                                  false && userData!['coverphoto'] != null
                              ? Image.network(
                                  'http://145.223.21.62:8090/api/files/${userData!['collectionId']}/${userData!['id']}/${userData!['coverphoto']}',
                                  width: 35.w, // Set a fixed width
                                  height: 35.w, // Set a fixed height
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Handle image loading error
                                    return const Text("Not Set");
                                  },
                                )
                              : Container(
                                  width: 100.w, // Set a fixed width
                                  height: 100.w, // Set a fixed height
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.grey[300], // Placeholder color
                                    borderRadius: BorderRadius.circular(10.w),
                                  ),
                                  child: const Icon(Icons.image,
                                      color: Colors.grey), // Placeholder icon
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.w),
              Material(
                color: darkModeEnabled ? kDarkBoxColor : kLightBlueColor,
                borderRadius: BorderRadius.circular(10.w),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20.0, horizontal: 10.0),
                  child: Column(
                    children: [
                      ProfileEditTile(
                        icon: 'assets/icons/ic-user.svg',
                        text: 'First Name',
                        onTap: () => Navigator.pushNamed(context, 'edit-name'),
                        endWidget: Flexible(
                          child: TextWithArrow(
                            text: userData?['firstname'] ?? '',
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ProfileEditTile(
                        icon: 'assets/icons/ic-user.svg',
                        text: 'Last Name',
                        onTap: () => Navigator.pushNamed(context, 'edit-lname'),
                        endWidget: Flexible(
                          child: TextWithArrow(
                            text: userData?['lastname'] ?? '',
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ProfileEditTile(
                        icon: 'assets/icons/ic-info.svg',
                        text: 'ID',
                        onTap: () {},
                        endWidget: Flexible(
                          child: TextWithArrow(
                            text: _formatIdToInteger(widget.userId),
                            showArrow: false,
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ProfileEditTile(
                        icon: 'assets/icons/ic-users.svg',
                        text: 'Gender',
                        onTap: () {
                          showDialog(
                            context: context,
                            useSafeArea: true,
                            builder: (BuildContext context) {
                              return const AlertDialog(
                                surfaceTintColor: Colors.transparent,
                                content: GenderSelectorDialog(),
                              );
                            },
                          );
                        },
                        endWidget: TextWithArrow(
                          text: userData?['gender'] ?? 'Not set',
                        ),
                      ),
                      _buildDivider(),
                      ProfileEditTile(
                        icon: 'assets/icons/ic-flag.svg',
                        text: 'Country',
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showPhoneCode: false,
                            onSelect: _saveCountryToDatabase,
                          );
                        },
                        endWidget: Flexible(
                          child: TextWithArrow(
                            text: userData?['country'] ?? 'Not set',
                          ),
                        ),
                      ),
                      _buildDivider(),
                      // ProfileEditTile(
                      //   icon: 'assets/icons/ic_calendar.svg',
                      //   text: 'Birthday',
                      //   onTap: () => selectDate(context),
                      //   endWidget: TextWithArrow(
                      //     text: userData?['birthday'] != null
                      //         ? DateTime.parse(userData!['birthday'])
                      //         .toLocal()
                      //         .toString()
                      //         .split(' ')[0]
                      //         : 'Not set',
                      //   ),
                      // ),
                      ProfileEditTile(
                        icon: 'assets/icons/ic_calendar.svg',
                        text: 'Birthday',
                        onTap: () => selectDate(context),
                        endWidget: TextWithArrow(
                          text: userData?['birthday'] != null &&
                                  userData!['birthday'].isNotEmpty
                              ? DateTime.parse(userData!['birthday'])
                                  .toLocal()
                                  .toString()
                                  .split(' ')[0]
                              : 'Not set', // Display 'Not set' if birthday is not available
                        ),
                      ),

                      _buildDivider(),
                      ProfileEditTile(
                        icon: 'assets/icons/ic-list.svg',
                        text: 'Bio',
                        onTap: () => Navigator.pushNamed(context, 'edit-bio'),
                        endWidget: Flexible(
                          // Use Flexible instead of Expanded
                          child: TextWithArrow(
                            text: userData?['bio'] ?? '',
                          ),
                        ),
                      ),
                      _buildDivider(),
                      ProfileEditTile(
                        icon: 'assets/icons/ic-motto.svg',
                        text: 'Motto',
                        onTap: () => Navigator.pushNamed(context, 'edit-motto'),
                        endWidget: Flexible(
                          child: TextWithArrow(
                            text: userData?['moto'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: kSeperatorColor,
      indent: 20.0,
      endIndent: 20.0,
    );
  }
}
